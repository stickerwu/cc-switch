//! Tauri 1 logging adapter for the UOS build (no Tauri 2 plugin dependency).
use std::{
    fs::{self, OpenOptions},
    io::Write,
    path::PathBuf,
    sync::Mutex,
};

struct Logger {
    path: PathBuf,
    lock: Mutex<()>,
}
impl log::Log for Logger {
    fn enabled(&self, metadata: &log::Metadata) -> bool {
        metadata.level() <= log::max_level()
    }
    fn log(&self, record: &log::Record) {
        if !self.enabled(record.metadata()) {
            return;
        }
        let Ok(_guard) = self.lock.lock() else {
            return;
        };
        if fs::metadata(&self.path)
            .map(|m| m.len() >= 20 * 1024 * 1024)
            .unwrap_or(false)
        {
            for i in (1..4).rev() {
                let _ = fs::rename(
                    self.path.with_extension(format!("log.{i}")),
                    self.path.with_extension(format!("log.{}", i + 1)),
                );
            }
            let _ = fs::rename(&self.path, self.path.with_extension("log.1"));
        }
        if let Ok(mut file) = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)
        {
            let _ = writeln!(
                file,
                "[{}][{}][{}] {}",
                chrono::Local::now().format("%Y-%m-%d %H:%M:%S"),
                record.target(),
                record.level(),
                record.args()
            );
        }
    }
    fn flush(&self) {}
}
pub fn init() {
    let dir = crate::panic_hook::get_log_dir();
    if let Err(e) = fs::create_dir_all(&dir) {
        eprintln!("Cannot create log directory: {e}");
        return;
    }
    let logger = Box::leak(Box::new(Logger {
        path: dir.join("cc-switch.log"),
        lock: Mutex::new(()),
    }));
    if log::set_logger(logger).is_ok() {
        log::set_max_level(log::LevelFilter::Info);
    }
}
#[tauri::command]
pub fn uos_frontend_error(message: String) {
    // The frontend logger redacts credentials before invoking this command.
    let bounded: String = message.chars().take(12_000).collect();
    log::error!(target: "frontend", "{bounded}");
}
