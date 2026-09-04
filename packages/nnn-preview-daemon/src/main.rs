use std::env;
use std::fs::{self, OpenOptions};
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::mpsc::{self, Sender};
use std::thread;

const FIFO_NAME: &str = "nnn-preview.fifo";

enum Message {
    Open(PathBuf),
    Hover(PathBuf),
}

struct Session {
    files: Vec<PathBuf>,
    index: usize,
}

fn main() {
    let args: Vec<_> = env::args_os().skip(1).collect::<Vec<_>>();
    if let Some(path) = args.first() {
        send_open(PathBuf::from(path));
        return;
    }

    run_daemon();
}

fn socket_path() -> PathBuf {
    env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join("nnn-preview.sock")
}

fn fifo_path() -> PathBuf {
    env::var_os("NNN_FIFO")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            env::var_os("XDG_RUNTIME_DIR")
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from("/tmp"))
                .join(FIFO_NAME)
        })
}

fn send_open(path: PathBuf) {
    let socket = socket_path();
    if let Ok(mut stream) = UnixStream::connect(&socket) {
        let text = path.to_string_lossy();
        let _ = stream.write_all(text.as_bytes());
        let _ = stream.shutdown(std::net::Shutdown::Write);
        return;
    }

    // Keep Space useful during a service restart or before the session starts.
    let _ = Command::new("sushi")
        .arg(path)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}

fn run_daemon() {
    let socket = socket_path();
    let _ = fs::remove_file(&socket);
    let Ok(listener) = UnixListener::bind(&socket) else {
        eprintln!("nnn-preview-daemon: cannot bind {}", socket.display());
        return;
    };
    let _ = fs::set_permissions(&socket, fs::Permissions::from_mode(0o600));

    let (sender, receiver) = mpsc::channel();
    start_socket_listener(listener, sender.clone());
    start_fifo_listener(sender);

    let mut session = None;
    while let Ok(message) = receiver.recv() {
        match message {
            Message::Open(path) => {
                if same_current_file(session.as_ref(), &path) && sushi_is_open() {
                    close_sushi();
                    session = None;
                } else {
                    session = open_session(path);
                }
            }
            Message::Hover(path) => handle_hover(&mut session, path),
        }
    }

    let _ = fs::remove_file(socket);
}

fn start_socket_listener(listener: UnixListener, sender: Sender<Message>) {
    thread::spawn(move || {
        for stream in listener.incoming().flatten() {
            let sender = sender.clone();
            thread::spawn(move || {
                let mut stream = stream;
                let mut bytes = Vec::new();
                if stream.read_to_end(&mut bytes).is_ok() && !bytes.is_empty() {
                    let path = PathBuf::from(String::from_utf8_lossy(&bytes).into_owned());
                    let _ = sender.send(Message::Open(path));
                }
            });
        }
    });
}

fn start_fifo_listener(sender: Sender<Message>) {
    let fifo = fifo_path();
    if !fifo.exists() {
        let _ = Command::new("mkfifo")
            .args(["-m", "600"])
            .arg(&fifo)
            .status();
    }

    thread::spawn(move || loop {
        let Ok(file) = OpenOptions::new().read(true).write(true).open(&fifo) else { return; };
        for line in BufReader::new(file).lines().map_while(Result::ok) {
            if !line.is_empty() {
                let _ = sender.send(Message::Hover(PathBuf::from(line)));
            }
        }
    });
}

fn open_session(path: PathBuf) -> Option<Session> {
    let current = fs::canonicalize(&path).unwrap_or(path);
    let files = sibling_files(&current);
    let index = files.iter().position(|file| file == &current).unwrap_or(0);
    show_file(files.get(index).unwrap_or(&current));

    Some(Session { files, index })
}

fn sibling_files(current: &Path) -> Vec<PathBuf> {
    let Some(directory) = current.parent() else { return vec![current.to_path_buf()]; };
    let Ok(entries) = fs::read_dir(directory) else { return vec![current.to_path_buf()]; };

    let mut files = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| fs::metadata(path).is_ok_and(|metadata| metadata.is_file()))
        .map(|path| fs::canonicalize(&path).unwrap_or(path))
        .collect::<Vec<_>>();
    files.sort_by(|left, right| left.file_name().cmp(&right.file_name()));

    if files.is_empty() { vec![current.to_path_buf()] } else { files }
}

fn handle_hover(session: &mut Option<Session>, path: PathBuf) {
    let Some(session) = session.as_mut() else { return; };
    if !sushi_is_open() {
        return;
    }

    let current = fs::canonicalize(path).ok();
    if let Some(index) = current.and_then(|current| session.files.iter().position(|file| file == &current)) {
        if index != session.index {
            session.index = index;
            show_file(&session.files[index]);
        }
    }
}

fn same_current_file(session: Option<&Session>, path: &Path) -> bool {
    let Some(session) = session else { return false; };
    let Some(current) = session.files.get(session.index) else { return false; };
    fs::canonicalize(path).ok().as_ref() == Some(current)
}

fn show_file(path: &Path) {
    let _ = Command::new("sushi")
        .arg(path)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}

fn sushi_is_open() -> bool {
    let Ok(output) = Command::new("hyprctl").args(["clients", "-j"]).output() else {
        return false;
    };
    let clients = String::from_utf8_lossy(&output.stdout).to_lowercase();
    clients.contains("sushi") || clients.contains("nautiluspreviewer")
}

fn close_sushi() {
    let _ = Command::new("dbus-send")
        .args([
            "--session",
            "--dest=org.gnome.NautilusPreviewer",
            "/org/gnome/NautilusPreviewer",
            "org.gnome.NautilusPreviewer.Close",
        ])
        .status();
}
