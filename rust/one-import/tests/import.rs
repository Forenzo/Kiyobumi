use serde_json::Value;
use std::{
    fs,
    io::{self, Write},
    path::{Path, PathBuf},
    process::Command,
};
use uuid::Uuid;

struct Temp(PathBuf);
impl Temp {
    fn new() -> Self {
        let p = std::env::temp_dir().join(format!("one-import-test-{}", Uuid::new_v4()));
        fs::create_dir(&p).unwrap();
        Self(p)
    }
}
impl Drop for Temp {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}
fn fixture() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures")
}
fn convert(input: &Path, output: &Path) {
    let result = Command::new(env!("CARGO_BIN_EXE_one-import"))
        .args([input, output])
        .output()
        .unwrap();
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
}
fn json(path: &Path) -> Value {
    serde_json::from_slice(&fs::read(path).unwrap()).unwrap()
}
fn page_contents(output: &Path) -> Vec<(String, Value)> {
    let mut result: Vec<(String, Value)> = Vec::new();
    let manifest = json(&output.join("manifest.json"));
    for section in manifest["sections"].as_array().unwrap() {
        for id in section["pageIDs"].as_array().unwrap() {
            let p = json(
                &output
                    .join("pages")
                    .join(format!("{}.json", id.as_str().unwrap())),
            );
            let mut elements = p["elements"].as_array().unwrap().clone();
            for e in &mut elements {
                e.as_object_mut().unwrap().remove("id");
                e["content"].as_object_mut().unwrap().remove("mediaName");
                if let Some(strokes) = e["content"]["strokes"].as_array_mut() {
                    for stroke in strokes {
                        stroke.as_object_mut().unwrap().remove("id");
                    }
                }
            }
            result.push((p["title"].as_str().unwrap().into(), Value::Array(elements)));
        }
    }
    result
}
#[test]
fn desktop_section_preserves_embedded_payload_and_source() {
    let work = Temp::new();
    let input = fixture().join("mit/OneWithFileData.one");
    let before = fs::read(&input).unwrap();
    assert_eq!(u32::from_le_bytes(before[64..68].try_into().unwrap()), 42);
    let out = work.0.join("Section.onbook");
    convert(&input, &out);
    let report = json(&out.join("import-report.json"));
    assert_eq!(report["pages"], 1);
    assert_eq!(report["attachments"], 1);
    let files: Vec<_> = fs::read_dir(out.join("media")).unwrap().collect();
    assert_eq!(files.len(), 1);
    assert!(
        fs::metadata(files[0].as_ref().unwrap().path())
            .unwrap()
            .len()
            > 0
    );
    assert_eq!(fs::read(input).unwrap(), before);
    assert_eq!(json(&out.join("manifest.json"))["schemaVersion"], 3);
}
#[test]
fn toc_and_package_have_same_pages_and_order() {
    let work = Temp::new();
    let dir = fixture().join("notebook");
    let native = work.0.join("Native.onbook");
    convert(&dir.join("Open Notebook.onetoc2"), &native);
    let names = [
        "Open Notebook.onetoc2",
        "New Section 1 2.one",
        "New Section 2.one",
        "New Section 3.one",
    ];
    let package = work.0.join("Test.onepkg");
    let mut builder = cab::CabinetBuilder::new();
    let folder = builder.add_folder(cab::CompressionType::MsZip);
    for name in names {
        folder.add_file(name);
    }
    let mut cabinet = builder.build(fs::File::create(&package).unwrap()).unwrap();
    while let Some(mut file) = cabinet.next_file().unwrap() {
        let mut input = fs::File::open(dir.join(file.file_name())).unwrap();
        io::copy(&mut input, &mut file).unwrap();
    }
    cabinet.finish().unwrap().flush().unwrap();
    let out = work.0.join("Package.onbook");
    convert(&package, &out);
    assert_eq!(page_contents(&native), page_contents(&out));
    let n = json(&native.join("manifest.json"));
    let p = json(&out.join("manifest.json"));
    assert_eq!(
        n["sections"]
            .as_array()
            .unwrap()
            .iter()
            .map(|s| &s["name"])
            .collect::<Vec<_>>(),
        p["sections"]
            .as_array()
            .unwrap()
            .iter()
            .map(|s| &s["name"])
            .collect::<Vec<_>>()
    );
    assert_eq!(json(&out.join("import-report.json"))["pages"], 5);
}
#[test]
fn native_notebook_retains_styled_runs_and_vector_ink() {
    let work = Temp::new();
    let out = work.0.join("Styled.onbook");
    convert(&fixture().join("notebook/Open Notebook.onetoc2"), &out);
    let mut text_count = 0;
    let mut point_count = 0;
    for (_, elements) in page_contents(&out) {
        for element in elements.as_array().unwrap() {
            let content = &element["content"];
            if content["type"] == "richText" {
                text_count += 1;
                let value = &content["value"];
                let length = value["text"].as_str().unwrap().encode_utf16().count();
                for run in value["runs"].as_array().unwrap() {
                    assert!(
                        run["location"].as_u64().unwrap() as usize
                            + run["length"].as_u64().unwrap() as usize
                            <= length
                    );
                    let format = &run["format"];
                    assert!(!format["fontName"].as_str().unwrap().is_empty());
                    assert!((6.0..=288.0).contains(&format["fontSize"].as_f64().unwrap()));
                    assert!(format["bold"].is_boolean() && format["underline"].is_boolean());
                }
            } else if content["type"] == "ink" {
                for stroke in content["strokes"].as_array().unwrap() {
                    let points = stroke["points"].as_array().unwrap();
                    point_count += points.len();
                    assert!(stroke["width"].as_f64().unwrap() > 0.0);
                    assert!((0.0..=1.0).contains(&stroke["opacity"].as_f64().unwrap()));
                    assert!(points.iter().all(|p| p["x"].as_f64().unwrap().is_finite()
                        && p["y"].as_f64().unwrap().is_finite()));
                }
            }
        }
    }
    assert!(text_count > 0);
    assert!(
        point_count > 0,
        "Published fixture contains real source ink"
    );
}
#[test]
fn malformed_file_never_produces_a_valid_notebook() {
    let work = Temp::new();
    let input = work.0.join("Broken.one");
    let data = b"invalid OneNote";
    fs::write(&input, data).unwrap();
    let out = work.0.join("Failed.onbook");
    let result = Command::new(env!("CARGO_BIN_EXE_one-import"))
        .args([&input, &out])
        .output()
        .unwrap();
    assert!(!result.status.success());
    assert!(!out.join("manifest.json").exists());
    assert_eq!(fs::read(input).unwrap(), data);
}
#[test]
fn missing_section_is_reported() {
    let work = Temp::new();
    let dir = fixture().join("notebook");
    for name in [
        "Open Notebook.onetoc2",
        "New Section 1 2.one",
        "New Section 3.one",
    ] {
        fs::copy(dir.join(name), work.0.join(name)).unwrap();
    }
    let output = work.0.join("Partial.onbook");
    convert(&work.0.join("Open Notebook.onetoc2"), &output);
    let r = json(&output.join("import-report.json"));
    assert!(r["warnings"]
        .as_array()
        .unwrap()
        .iter()
        .any(|w| w.as_str().unwrap().contains("New Section 2.one")));
}
