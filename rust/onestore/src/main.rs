use std::{fs::File, io::Read, process::ExitCode};
fn main() -> ExitCode {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() != 1 {
        eprintln!("Usage: one-inspect SECTION.one");
        return ExitCode::from(2);
    }
    let result = (|| -> Result<_, Box<dyn std::error::Error>> {
        let mut file = File::open(&args[0])?;
        let size = file.metadata()?.len();
        let mut header = Vec::new();
        (&mut file).take(1024).read_to_end(&mut header)?;
        Ok((header, size))
    })();
    match result {
        Ok((header, size)) => match onestore::probe_header(&header, size) {
            Ok(h) => {
                println!("Recognized modern .one section header: {h:?}\nPage/content import is not implemented.");
                ExitCode::SUCCESS
            }
            Err(e) => {
                eprintln!("Cannot recognize section header: {e:?}");
                ExitCode::from(1)
            }
        },
        Err(e) => {
            eprintln!("Cannot read input: {e}");
            ExitCode::from(1)
        }
    }
}
