use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fs;
use std::hash::{Hash, Hasher};
use std::io;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const INTERVAL: Duration = Duration::from_secs(5);
const ACTIVE_WIDGET_INTERVAL: Duration = Duration::from_secs(1);
const CPU_SAMPLE: Duration = Duration::from_millis(80);
const NIGHT_SHIFT_CHECK: Duration = Duration::from_secs(15 * 60);
const USAGE_REFRESH: Duration = Duration::from_secs(15 * 60);
const USAGE_REQUEST: &str = "nixos-desktop-usage.refresh";

#[derive(Clone, Default)]
struct CpuSample {
    total: u64,
    idle: u64,
}

#[derive(Clone)]
struct UsageRecord {
    timestamp: String,
    day: String,
    total: u64,
    input: u64,
    output: u64,
    cache_read: u64,
    cache_write: u64,
    rate_limits: Value,
    model: String,
    prompts: u64,
    session: String,
}

struct UsageCache {
    value: Value,
    signature: u64,
    next_refresh: Instant,
}

struct NightShift {
    child: Child,
    latitude: String,
    longitude: String,
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.get(1).map(String::as_str) == Some("focus-notification") {
        focus_notification(&args[2..]);
        return;
    }

    let runtime = runtime_dir();
    let output = runtime.join("nixos-desktop-state.json");
    let mut usage = UsageCache::new();
    let mut night_shift = start_night_shift();
    let mut next_night_shift_check = Instant::now();

    loop {
        if usage.needs_refresh(&runtime) {
            usage.refresh();
        }

        let previous = cpu_sample();
        thread::sleep(CPU_SAMPLE);
        let current = cpu_sample();

        if Instant::now() >= next_night_shift_check {
            if let Some(child) = night_shift.as_mut() {
                if child.child.try_wait().ok().flatten().is_some() {
                    night_shift = None;
                }
            }
            if night_shift.is_none() {
                night_shift = start_night_shift();
            }
            next_night_shift_check = Instant::now() + NIGHT_SHIFT_CHECK;
        }

        let json = snapshot_json(&previous, &current, &usage.value, night_shift.as_ref());
        if let Err(error) = atomic_write(&output, json.as_bytes()) {
            eprintln!("nixos-desktop-daemon: {error}");
        }

        let interval = if widgets_are_active() {
            ACTIVE_WIDGET_INTERVAL
        } else {
            INTERVAL
        };
        thread::sleep(interval);
    }
}

fn focus_notification(source_args: &[String]) {
    let source = source_args.join(" ").to_lowercase();
    if !source.contains("ghostty") && !source.contains("codex") {
        return;
    }

    let Ok(output) = Command::new("hyprctl").args(["-j", "clients"]).output() else { return; };
    let Ok(clients) = serde_json::from_slice::<Value>(&output.stdout) else { return; };
    let Some(clients) = clients.as_array() else { return; };
    let source_is_codex = source.contains("codex");

    let mut candidates = clients
        .iter()
        .filter_map(|client| {
            let address = client.get("address").and_then(Value::as_str)?;
            let window_text = ["class", "initialClass", "title", "initialTitle"]
                .iter()
                .filter_map(|key| client.get(*key).and_then(Value::as_str))
                .collect::<Vec<_>>()
                .join(" ")
                .to_lowercase();
            if !window_text.contains("ghostty") {
                return None;
            }

            let rank = if source_is_codex && window_text.contains("codex") { 0 } else { 1 };
            Some((if source_is_codex { rank } else { 0 }, address.to_string()))
        })
        .collect::<Vec<_>>();
    candidates.sort_by_key(|(rank, _)| *rank);

    let Some((_, address)) = candidates.into_iter().next() else { return; };
    // Hyprland's Lua config expects the Lua dispatcher form first. Keep the
    // legacy dispatcher as a fallback for older Hyprland releases.
    let lua_dispatch = format!(
        "hl.dsp.focus({{ window = \"address:{address}\" }})"
    );
    let focused = Command::new("hyprctl")
        .args(["dispatch", lua_dispatch.as_str()])
        .status()
        .map(|status| status.success())
        .unwrap_or(false);

    if !focused {
        let _ = Command::new("hyprctl")
            .args(["dispatch", "focuswindow"])
            .arg(format!("address:{address}"))
            .status();
    }
}

fn widgets_are_active() -> bool {
    let Ok(entries) = fs::read_dir("/proc") else { return false; };
    entries.flatten().any(|entry| {
        let name = entry.file_name();
        let Some(pid) = name.to_str() else { return false; };
        if !pid.bytes().all(|byte| byte.is_ascii_digit()) { return false; }
        let Ok(command_line) = fs::read(entry.path().join("cmdline")) else { return false; };
        let command_line = String::from_utf8_lossy(&command_line);
        command_line.contains("/control-center.qml") || command_line.contains("/battery-panel.qml")
    })
}

impl UsageCache {
    fn new() -> Self {
        let mut cache = Self {
            value: empty_usage(),
            signature: 0,
            next_refresh: Instant::now(),
        };
        cache.refresh();
        cache
    }

    fn refresh(&mut self) {
        let (value, signature) = collect_usage();
        self.value = value;
        self.signature = signature;
        self.next_refresh = Instant::now() + USAGE_REFRESH;
    }

    fn needs_refresh(&self, runtime: &Path) -> bool {
        let request = runtime.join(USAGE_REQUEST);
        if request.exists() {
            let _ = fs::remove_file(request);
            return true;
        }

        if Instant::now() >= self.next_refresh {
            return true;
        }

        usage_signature().is_some_and(|signature| signature != self.signature)
    }
}

fn runtime_dir() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn cpu_sample() -> CpuSample {
    let (total, idle) = read_cpu_totals().unwrap_or((0, 0));
    CpuSample { total, idle }
}

fn read_cpu_totals() -> io::Result<(u64, u64)> {
    let contents = fs::read_to_string("/proc/stat")?;
    let line = contents
        .lines()
        .find(|line| line.starts_with("cpu "))
        .unwrap_or("");
    let values: Vec<u64> = line
        .split_whitespace()
        .skip(1)
        .filter_map(|value| value.parse().ok())
        .collect();
    let total = values.iter().sum();
    let idle = values.get(3).copied().unwrap_or(0) + values.get(4).copied().unwrap_or(0);
    Ok((total, idle))
}

fn snapshot_json(
    previous: &CpuSample,
    current: &CpuSample,
    usage: &Value,
    night_shift: Option<&NightShift>,
) -> String {
    let total_delta = current.total.saturating_sub(previous.total);
    let idle_delta = current.idle.saturating_sub(previous.idle);
    let cpu = if total_delta == 0 {
        0
    } else {
        (((total_delta.saturating_sub(idle_delta)) as f64 / total_delta as f64) * 100.0).round() as u64
    };
    let memory = memory_stats();
    let temp = temperature().unwrap_or(0);
    let storage = storage_percent().unwrap_or(0);
    let capabilities = capabilities_json();
    let usage = serde_json::to_string(usage).unwrap_or_else(|_| "{}".to_string());
    let night_shift = night_shift_json(night_shift);

    format!(
        "{{\"cpu\":{cpu},\"mem\":{{\"percent\":{},\"swapPercent\":{}}},\"temp\":{temp},\"storage\":{storage},\"capabilities\":{capabilities},\"usage\":{usage},\"nightShift\":{night_shift}}}",
        memory.0,
        memory.1,
    )
}

fn memory_stats() -> (u64, u64) {
    let text = fs::read_to_string("/proc/meminfo").unwrap_or_default();
    let mut values = HashMap::new();
    for line in text.lines() {
        let mut parts = line.split_whitespace();
        if let (Some(key), Some(value)) = (parts.next(), parts.next()) {
            if let Ok(value) = value.parse::<u64>() { values.insert(key.trim_end_matches(':'), value); }
        }
    }
    let total = values.get("MemTotal").copied().unwrap_or(0);
    let available = values.get("MemAvailable").copied().unwrap_or(0);
    let used = total.saturating_sub(available);
    let percent = if total == 0 { 0 } else { used * 100 / total };
    let swap_total = values.get("SwapTotal").copied().unwrap_or(0);
    let swap_free = values.get("SwapFree").copied().unwrap_or(0);
    let swap_percent = if swap_total == 0 { 0 } else { swap_total.saturating_sub(swap_free) * 100 / swap_total };
    (percent, swap_percent)
}

fn temperature() -> Option<u64> {
    let mut best: Option<u64> = None;
    for entry in fs::read_dir("/sys/class/hwmon").ok()?.flatten() {
        for input in fs::read_dir(entry.path()).ok()?.flatten() {
            let name = input.file_name();
            let name = name.to_string_lossy();
            if !name.starts_with("temp") || !name.ends_with("_input") { continue; }
            let value: u64 = fs::read_to_string(input.path()).ok()?.trim().parse().ok()?;
            let celsius = value / 1000;
            if (1..=120).contains(&celsius) { best = Some(best.map_or(celsius, |old| old.max(celsius))); }
        }
    }
    best
}

fn storage_percent() -> Option<u64> {
    let output = Command::new("df").args(["-P", "/"]).output().ok()?;
    let text = String::from_utf8_lossy(&output.stdout);
    text.lines().nth(1)?.split_whitespace().nth(4)?.trim_end_matches('%').parse().ok()
}

fn capabilities_json() -> String {
    let wifi = fs::read_dir("/sys/class/net").ok().map(|entries| entries.flatten().any(|entry| entry.file_name() != "lo")).unwrap_or(false);
    let bluetooth = Path::new("/sys/class/bluetooth").read_dir().map(|mut entries| entries.next().is_some()).unwrap_or(false);
    let backlight = Path::new("/sys/class/backlight").read_dir().map(|mut entries| entries.next().is_some()).unwrap_or(false);
    let battery = Path::new("/sys/class/power_supply").read_dir().map(|entries| entries.flatten().any(|entry| entry.file_name().to_string_lossy().starts_with("BAT"))).unwrap_or(false);
    let tailscale = command_exists("tailscale");
    format!("{{\"wifi\":{wifi},\"bluetooth\":{bluetooth},\"backlight\":{backlight},\"battery\":{battery},\"tailscale\":{tailscale}}}")
}

fn command_exists(command: &str) -> bool {
    let path = std::env::var_os("PATH").unwrap_or_default();
    std::env::split_paths(&path).any(|directory| directory.join(command).is_file())
}

fn empty_usage() -> Value {
    json!({
        "schemaVersion": 1,
        "id": "codex",
        "name": "Codex",
        "ready": false,
        "hasLocalStats": false,
        "tierLabel": "",
        "usageStatusText": "Loading usage…",
        "authHelpText": "Run `codex login` to authenticate.",
        "recentDays": [],
        "modelUsage": {},
        "limits": [],
    })
}

fn collect_usage() -> (Value, u64) {
    let root = std::env::var_os("CODEX_SESSIONS_DIR")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".codex/sessions")))
        .unwrap_or_else(|| PathBuf::from(".codex/sessions"));
    let signature = usage_signature_for(&root).unwrap_or(0);
    let mut paths = Vec::new();
    collect_session_paths(&root, &mut paths);

    let mut records = paths
        .iter()
        .filter_map(|path| session_record(path))
        .collect::<Vec<_>>();
    records.sort_by(|left, right| left.timestamp.cmp(&right.timestamp));

    let today = current_day();
    let recent_days = recent_days(&today);
    let recent_set = recent_days.iter().cloned().collect::<BTreeSet<_>>();
    let mut recent = recent_days
        .iter()
        .map(|day| (day.clone(), 0_u64))
        .collect::<BTreeMap<_, _>>();
    let mut model_usage: BTreeMap<String, BTreeMap<String, u64>> = BTreeMap::new();
    let mut active_dates = BTreeSet::new();
    let mut today_sessions = BTreeSet::new();
    let mut total_sessions = BTreeSet::new();
    let mut today_prompts = 0_u64;
    let mut today_total_tokens = 0_u64;
    let mut total_prompts = 0_u64;
    let mut latest_limits = json!({});
    let mut latest_plan = String::new();

    for record in &records {
        active_dates.insert(record.day.clone());
        total_sessions.insert(record.session.clone());
        total_prompts += record.prompts;
        if recent_set.contains(&record.day) {
            *recent.entry(record.day.clone()).or_default() += record.total;
        }
        if record.day == today {
            today_prompts += record.prompts;
            today_sessions.insert(record.session.clone());
            today_total_tokens += record.total;
        }

        let bucket = model_usage.entry(record.model.clone()).or_default();
        *bucket.entry("inputTokens".to_string()).or_default() += record.input;
        *bucket.entry("outputTokens".to_string()).or_default() += record.output;
        *bucket.entry("cacheReadInputTokens".to_string()).or_default() += record.cache_read;
        *bucket.entry("cacheCreationInputTokens".to_string()).or_default() += record.cache_write;

        if record.rate_limits.is_object() && !record.rate_limits.as_object().unwrap().is_empty() {
            latest_limits = record.rate_limits.clone();
            latest_plan = record.rate_limits
                .get("plan_type")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_lowercase();
        }
    }

    let limits = format_limits(&latest_limits);
    let ready = !records.is_empty();
    let tier = if !latest_plan.is_empty() {
        latest_plan
    } else if ready {
        "Subscription".to_string()
    } else {
        String::new()
    };
    let recent_rows = recent_days
        .iter()
        .map(|day| json!({ "date": day, "messageCount": recent.get(day).copied().unwrap_or(0) }))
        .collect::<Vec<_>>();

    (
        json!({
            "schemaVersion": 1,
            "id": "codex",
            "name": "Codex",
            "updatedAt": utc_now(),
            "ready": ready,
            "hasLocalStats": ready,
            "tierLabel": tier,
            "usageStatusText": if ready { "" } else { "No Codex usage data found" },
            "authHelpText": "Run `codex login` to authenticate.",
            "todayPrompts": today_prompts,
            "todaySessions": today_sessions.len(),
            "todayTotalTokens": today_total_tokens,
            "recentDays": recent_rows,
            "totalPrompts": total_prompts,
            "totalSessions": total_sessions.len(),
            "activeDays": active_dates.len(),
            "activeDates": active_dates,
            "modelUsage": model_usage,
            "limits": limits,
        }),
        signature,
    )
}

fn collect_session_paths(root: &Path, paths: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(root) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            collect_session_paths(&path, paths);
        } else if path.extension().is_some_and(|extension| extension == "jsonl") {
            paths.push(path);
        }
    }
}

fn usage_signature() -> Option<u64> {
    let root = std::env::var_os("CODEX_SESSIONS_DIR")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".codex/sessions")))
        .unwrap_or_else(|| PathBuf::from(".codex/sessions"));
    usage_signature_for(&root)
}

fn usage_signature_for(root: &Path) -> Option<u64> {
    if !root.is_dir() {
        return Some(0);
    }
    let mut paths = Vec::new();
    collect_session_paths(root, &mut paths);
    paths.sort();
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    for path in paths {
        path.hash(&mut hasher);
        if let Ok(metadata) = fs::metadata(&path) {
            metadata.len().hash(&mut hasher);
            if let Ok(modified) = metadata.modified() {
                modified.duration_since(UNIX_EPOCH).unwrap_or_default().as_nanos().hash(&mut hasher);
            }
        }
    }
    Some(hasher.finish())
}

fn session_record(path: &Path) -> Option<UsageRecord> {
    let contents = fs::read_to_string(path).ok()?;
    let mut latest = None;
    let mut model = "codex".to_string();
    let mut prompts = 0_u64;

    for line in contents.lines() {
        let Ok(entry) = serde_json::from_str::<Value>(line) else { continue };
        let candidate = find_model(&entry);
        if !candidate.is_empty() {
            model = candidate;
        }
        if entry.get("type").and_then(Value::as_str) != Some("event_msg") {
            continue;
        }
        let Some(payload) = entry.get("payload").and_then(Value::as_object) else { continue };
        if payload.get("type").and_then(Value::as_str) != Some("token_count") {
            continue;
        }
        let Some(usage) = payload
            .get("info")
            .and_then(Value::as_object)
            .and_then(|info| info.get("total_token_usage"))
            .and_then(Value::as_object)
        else { continue };
        let total = number(usage.get("total_tokens"));
        if total == 0 { continue; }
        prompts += 1;
        let timestamp = value_string(entry.get("timestamp"));
        latest = Some(UsageRecord {
            day: local_day(entry.get("timestamp")),
            timestamp,
            total,
            input: number(usage.get("input_tokens")),
            output: number(usage.get("output_tokens")),
            cache_read: number(usage.get("cached_input_tokens")),
            cache_write: number(usage.get("cache_write_input_tokens")),
            rate_limits: payload.get("rate_limits").cloned().unwrap_or_else(|| json!({})),
            model: model.clone(),
            prompts,
            session: path.to_string_lossy().to_string(),
        });
    }

    latest.map(|mut record| {
        record.model = model;
        record
    })
}

fn find_model(value: &Value) -> String {
    match value {
        Value::Object(object) => {
            for key in ["model", "model_name", "model_slug"] {
                if let Some(candidate) = object.get(key).and_then(Value::as_str) {
                    if !candidate.is_empty() && !candidate.starts_with("model_") {
                        return candidate.to_string();
                    }
                }
            }
            object.values().find_map(|child| {
                let found = find_model(child);
                (!found.is_empty()).then_some(found)
            }).unwrap_or_default()
        }
        Value::Array(values) => values.iter().find_map(|child| {
            let found = find_model(child);
            (!found.is_empty()).then_some(found)
        }).unwrap_or_default(),
        _ => String::new(),
    }
}

fn number(value: Option<&Value>) -> u64 {
    value.and_then(|value| {
        value.as_u64()
            .or_else(|| value.as_i64().map(|number| number.max(0) as u64))
            .or_else(|| value.as_f64().map(|number| number.max(0.0).round() as u64))
    }).unwrap_or(0)
}

fn float_number(value: Option<&Value>) -> f64 {
    value.and_then(|value| value.as_f64().or_else(|| value.as_u64().map(|number| number as f64))).unwrap_or(0.0)
}

fn value_string(value: Option<&Value>) -> String {
    match value {
        Some(Value::String(value)) => value.clone(),
        Some(Value::Number(value)) => value.to_string(),
        _ => String::new(),
    }
}

fn local_day(value: Option<&Value>) -> String {
    date_command(value, false)
        .and_then(|timestamp| timestamp.get(..10).map(str::to_string))
        .or_else(|| value_string(value).get(..10).map(str::to_string))
        .unwrap_or_else(current_day)
}

fn format_timestamp(value: Option<&Value>) -> String {
    if value.is_some_and(|value| value.is_string()) {
        return value_string(value);
    }
    date_command(value, true).unwrap_or_default()
}

fn date_command(value: Option<&Value>, utc: bool) -> Option<String> {
    let raw = value_string(value);
    let argument = if raw.is_empty() {
        return None;
    } else if value.is_some_and(|value| value.is_number()) {
        format!("@{raw}")
    } else {
        raw
    };
    let mut command = Command::new("date");
    if utc { command.arg("-u"); }
    let output = command.args(["-d", &argument, "+%Y-%m-%dT%H:%M:%SZ"]).output().ok()?;
    if !output.status.success() { return None; }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn current_day() -> String {
    let output = Command::new("date").args(["+%F"]).output().ok();
    output
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "1970-01-01".to_string())
}

fn recent_days(today: &str) -> Vec<String> {
    (0..=6).rev()
        .filter_map(|offset| {
            let expression = format!("{today} -{offset} days");
            let output = Command::new("date").args(["-d", &expression, "+%F"]).output().ok()?;
            if !output.status.success() { return None; }
            Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
        })
        .collect()
}

fn utc_now() -> String {
    let output = Command::new("date").args(["-u", "+%Y-%m-%dT%H:%M:%SZ"]).output().ok();
    output
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
        .unwrap_or_else(|| {
            let seconds = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();
            seconds.to_string()
        })
}

fn format_limits(rate_limits: &Value) -> Vec<Value> {
    ["primary", "secondary"]
        .into_iter()
        .filter_map(|name| {
            let window = rate_limits.get(name).and_then(Value::as_object)?;
            let used_value = window.get("used_percent")?;
            let mut used = float_number(Some(used_value));
            if used > 1.0 { used /= 100.0; }

            let minutes = number(window.get("window_minutes"));
            Some(json!({
                "title": limit_title(minutes),
                "percent": used.clamp(0.0, 1.0),
                "resetsAt": format_timestamp(window.get("resets_at")),
                "windowMinutes": minutes,
            }))
        })
        .collect()
}

fn limit_title(minutes: u64) -> String {
    if minutes >= 7 * 24 * 60 {
        return "Weekly".to_string();
    }
    if minutes == 5 * 60 {
        return "5-hour".to_string();
    }
    if minutes > 0 && minutes % 60 == 0 {
        return format!("{}-hour", minutes / 60);
    }
    if minutes > 0 {
        return format!("{}-minute", minutes);
    }
    "Session".to_string()
}

fn start_night_shift() -> Option<NightShift> {
    let (latitude, longitude) = night_shift_location()?;
    let child = Command::new("wlsunset")
        .args(["-l", &latitude, "-L", &longitude, "-T", "6500", "-t", "4000"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;
    Some(NightShift { child, latitude, longitude })
}

fn night_shift_json(night_shift: Option<&NightShift>) -> String {
    match night_shift {
        Some(state) => serde_json::to_string(&json!({
            "running": true,
            "latitude": state.latitude,
            "longitude": state.longitude,
            "provider": "wlsunset",
            "mode": "sunset-to-sunrise",
        })).unwrap_or_else(|_| "{\"running\":true}".to_string()),
        None => "{\"running\":false}".to_string(),
    }
}

fn night_shift_location() -> Option<(String, String)> {
    let cache_dir = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join("nixos-night-shift");
    let location_file = cache_dir.join("location");

    let fresh = Command::new("curl")
        .args(["-fsS", "--max-time", "10", "https://ipinfo.io/loc"])
        .output()
        .ok()
        .filter(|output| output.status.success())
        .and_then(|output| String::from_utf8(output.stdout).ok());
    let location = fresh.or_else(|| fs::read_to_string(&location_file).ok()).unwrap_or_default();
    let (latitude, longitude) = location.trim().split_once(',')?;
    let latitude = latitude.trim().to_string();
    let longitude = longitude.trim().to_string();
    if latitude.is_empty() || longitude.is_empty() { return None; }

    let _ = fs::create_dir_all(&cache_dir);
    let _ = fs::write(&location_file, format!("{latitude},{longitude}\n"));
    Some((latitude, longitude))
}

fn atomic_write(path: &Path, contents: &[u8]) -> io::Result<()> {
    let parent = path.parent().unwrap_or_else(|| Path::new("/tmp"));
    fs::create_dir_all(parent)?;
    let temp = parent.join(format!(".{}.tmp", std::process::id()));
    fs::write(&temp, contents)?;
    fs::rename(temp, path)
}
