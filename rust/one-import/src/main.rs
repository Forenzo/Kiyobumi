//! Read-only OneNote desktop conversion. No Microsoft code is linked.
//! The binary reader is the MPL-2.0 onenote_parser dependency with documented
//! compatibility fixes; see rust/vendor/onenote_parser/PATCHES.md.
use onenote_parser::{
    contents::*,
    page::PageContent,
    section::{Section, SectionEntry},
    Parser,
};
use serde_json::{json, Value};
use std::{
    fs,
    io::{self, Read},
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc, Mutex,
    },
};
use typed_path::{TypedPath, TypedPathBuf};
use uuid::Uuid;

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
const MAX_FILE: u64 = 256 * 1024 * 1024;
const MAX_TOTAL: u64 = 512 * 1024 * 1024;
const MAX_MEDIA: u64 = 50 * 1024 * 1024;
fn id() -> String {
    Uuid::new_v4().to_string()
}
fn fail(message: &str) -> io::Error {
    io::Error::other(message)
}

// Desktop notebook entries can reference sibling sections. Restrict every
// parser read to the selected notebook directory, including symlink resolution.
#[derive(Clone, Copy)]
struct ConfinedFs<'a> {
    root: &'a Path,
    read_bytes: &'a AtomicU64,
    issues: &'a Mutex<Vec<String>>,
}
impl ConfinedFs<'_> {
    fn resolve(&self, path: TypedPath) -> io::Result<PathBuf> {
        let candidate = PathBuf::from(path.to_string_lossy().as_ref());
        let canonical = candidate.canonicalize()?;
        if !canonical.starts_with(self.root) {
            return Err(fail("A notebook reference escapes the selected directory."));
        }
        Ok(canonical)
    }
    fn charge(&self, size: u64) -> io::Result<()> {
        if size > MAX_FILE
            || self
                .read_bytes
                .fetch_add(size, Ordering::Relaxed)
                .saturating_add(size)
                > MAX_TOTAL
        {
            return Err(fail(
                "Import input exceeds the 256 MB per-file or 512 MB total limit.",
            ));
        }
        Ok(())
    }
}
impl onenote_parser::FileSystem for ConfinedFs<'_> {
    fn is_directory(&self, p: TypedPath) -> io::Result<bool> {
        match self.resolve(p) {
            Ok(p) => Ok(p.is_dir()),
            Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(false),
            Err(e) => Err(e),
        }
    }
    fn read_dir(&self, p: TypedPath) -> io::Result<Vec<TypedPathBuf>> {
        let mut out = Vec::new();
        for entry in fs::read_dir(self.resolve(p)?)? {
            let path = entry?.path();
            if out.len() >= 20_000 {
                return Err(fail("Too many notebook directory entries."));
            }
            out.push(
                TypedPath::derive(
                    path.to_str()
                        .ok_or_else(|| fail("Non-UTF-8 notebook path."))?,
                )
                .to_path_buf(),
            );
        }
        Ok(out)
    }
    fn read_file(&self, p: TypedPath) -> io::Result<Vec<u8>> {
        let path = self.resolve(p)?;
        self.charge(fs::metadata(&path)?.len())?;
        fs::read(path)
    }
    fn open_file(&self, p: TypedPath) -> io::Result<Arc<dyn onenote_parser::fs::FileSource>> {
        let path = self.resolve(p)?;
        if !path.is_file() {
            return Err(fail("A notebook reference is not a regular file."));
        }
        self.charge(fs::metadata(&path)?.len())?;
        onenote_parser::fs::native_fs::NativeFs {}.open_file(TypedPath::derive(
            path.to_str().ok_or_else(|| fail("Non-UTF-8 path."))?,
        ))
    }
    fn write_file(&self, _: TypedPath, _: &[u8]) -> io::Result<()> {
        Err(fail("Read-only import filesystem."))
    }
    fn stream_to_file(&self, _: TypedPath, _: &mut dyn Read) -> io::Result<()> {
        Err(fail("Read-only import filesystem."))
    }
    fn make_dir(&self, _: TypedPath) -> io::Result<()> {
        Err(fail("Read-only import filesystem."))
    }
    fn canonicalize(&self, p: TypedPath) -> io::Result<TypedPathBuf> {
        Ok(TypedPath::derive(
            self.resolve(p)?
                .to_str()
                .ok_or_else(|| fail("Non-UTF-8 path."))?,
        )
        .to_path_buf())
    }
    fn exists(&self, p: TypedPath) -> io::Result<bool> {
        match self.resolve(p) {
            Ok(_) => Ok(true),
            Err(e) => {
                let mut issues = self
                    .issues
                    .lock()
                    .map_err(|_| fail("Import diagnostics lock failed."))?;
                if issues.len() < 500 {
                    issues.push(format!(
                        "Missing or inaccessible notebook reference {}: {e}",
                        p.to_string_lossy()
                    ));
                }
                if e.kind() == io::ErrorKind::NotFound {
                    Ok(false)
                } else {
                    Err(e)
                }
            }
        }
    }
}

struct Converter {
    output: PathBuf,
    sections: Vec<Value>,
    warnings: Vec<String>,
    page_count: usize,
    element_count: usize,
    media_bytes: u64,
    media_count: usize,
    ink_points: usize,
}
impl Converter {
    fn warn(&mut self, message: impl Into<String>) {
        let m = message.into();
        if self.warnings.len() < 500 && !self.warnings.contains(&m) {
            self.warnings.push(m);
        }
    }
    fn element(
        &mut self,
        elements: &mut Vec<Value>,
        x: f64,
        y: f64,
        w: f64,
        h: f64,
        content: Value,
    ) -> Result<()> {
        self.element_count += 1;
        if self.element_count > 200_000 {
            return Err(fail("Too many page elements.").into());
        }
        elements.push(json!({"id":id(), "frame":{"x":x.max(0.0),"y":y.max(0.0),"width":w.clamp(24.0,100_000.0),"height":h.clamp(24.0,100_000.0)},"content":content}));
        Ok(())
    }
    fn blob(&mut self, reader: &mut dyn Read, ext: &str) -> Result<String> {
        let mut data = Vec::new();
        reader.take(MAX_MEDIA + 1).read_to_end(&mut data)?;
        if data.len() as u64 > MAX_MEDIA {
            return Err(fail("An attachment exceeds the 50 MB limit.").into());
        }
        self.media_bytes += data.len() as u64;
        if self.media_bytes > MAX_TOTAL {
            return Err(fail("Extracted attachments exceed 512 MB.").into());
        }
        let ext: String = ext
            .chars()
            .filter(|c| c.is_ascii_alphanumeric())
            .take(12)
            .collect();
        let name = format!("{}.{}", id(), if ext.is_empty() { "bin" } else { &ext });
        fs::write(self.output.join("media").join(&name), data)?;
        self.media_count += 1;
        Ok(name)
    }
    fn image(&mut self, image: &Image, elements: &mut Vec<Value>, x: f64, y: f64) -> Result<f64> {
        if let Some(mut reader) = image.read() {
            let name = self.blob(&mut reader, image.extension().unwrap_or("bin"))?;
            let w = units(image.picture_width().or(image.layout_max_width()), 320.0).max(24.0);
            let h = units(image.picture_height().or(image.layout_max_height()), 240.0).max(24.0);
            self.element(
                elements,
                x,
                y,
                w,
                h,
                json!({"type":"image","mediaName":name}),
            )?;
            if !image.embeds().is_empty() {
                self.warn("Embedded online video frames were not converted.");
            }
            if image.text().is_some() {
                self.warn("Existing image OCR text is not indexed in this release.");
            }
            Ok(h + 12.0)
        } else {
            self.warn("An image payload is missing or unavailable in the source.");
            Ok(24.0)
        }
    }
    fn attachment(
        &mut self,
        file: &EmbeddedFile,
        elements: &mut Vec<Value>,
        x: f64,
        y: f64,
    ) -> Result<f64> {
        let ext = Path::new(file.filename())
            .extension()
            .and_then(|s| s.to_str())
            .unwrap_or("bin");
        let name = self.blob(&mut file.read(), ext)?;
        // Display name is data only; it is never used as a storage path.
        self.element(
            elements,
            x,
            y,
            320.0,
            52.0,
            json!({"type":"attachment","mediaName":name,"fileName":file.filename()}),
        )?;
        Ok(64.0)
    }
    fn rich(&mut self, text: &RichText) -> String {
        if !text.embedded_objects().is_empty() || !text.math_inline_objects().is_empty() {
            self.warn(
                "Inline ink and equations were not converted; surrounding text was retained.",
            );
        }
        self.warn("Text uses Markdown: exact fonts, colors, paragraph spacing and alignment are not retained.");
        let utf16: Vec<u16> = text.text().encode_utf16().collect();
        let links = text.hyperlinks();
        let mut output = String::new();
        let mut start = 0;
        for (index, end) in text.text_run_indices().iter().enumerate() {
            let end = (*end as usize).min(utf16.len());
            if end < start {
                continue;
            }
            let style = text
                .text_run_formatting()
                .get(index)
                .unwrap_or(text.paragraph_style());
            if !style.hidden() {
                let value = String::from_utf16_lossy(&utf16[start..end]);
                let mut value = escape_markdown(&value);
                if style.bold() {
                    value = format!("**{value}**");
                }
                if style.italic() {
                    value = format!("*{value}*");
                }
                if let Some(link) = links
                    .iter()
                    .find(|l| l.start() as usize <= start && l.end() as usize >= end)
                {
                    if safe_link(link.target()) {
                        value = format!(
                            "[{value}]({})",
                            link.target().replace(')', "%29").replace(' ', "%20")
                        );
                    } else {
                        self.warn("Internal OneNote and non-web links were retained as text; their targets need relinking.");
                    }
                }
                output.push_str(&value);
            }
            start = end;
        }
        if start < utf16.len() {
            output.push_str(&escape_markdown(&String::from_utf16_lossy(&utf16[start..])));
        }
        if text.text_run_indices().is_empty() {
            // The fallback above already emitted the whole paragraph.
            if text.paragraph_style().bold() {
                output = format!("**{output}**");
            }
            if text.paragraph_style().italic() {
                output = format!("*{output}*");
            }
        }
        for tag in text.note_tags().iter().rev() {
            if tag.item_status().task_tag()
                || tag
                    .definition()
                    .is_some_and(|d| format!("{:?}", d.shape()).contains("CheckBox"))
            {
                output = format!(
                    "- [{}] {output}",
                    if tag.item_status().completed() {
                        "x"
                    } else {
                        " "
                    }
                );
            } else if let Some(def) = tag.definition() {
                output = format!("[{}] {output}", def.label());
            }
        }
        output
    }
    fn styled(&mut self, text: &RichText, list: bool) -> Value {
        if !text.math_inline_objects().is_empty() {
            self.warn("Inline equations are not converted.");
        }
        self.warn("Font family, size, bold, italic, underline and text color are retained. Paragraph spacing, alignment, highlight, strikeout and superscript/subscript are approximated or omitted.");
        let base = text.paragraph_style();
        let mut output = String::new();
        for tag in text.note_tags().iter().rev() {
            if tag.item_status().task_tag()
                || tag
                    .definition()
                    .is_some_and(|d| format!("{:?}", d.shape()).contains("CheckBox"))
            {
                output.push_str(if tag.item_status().completed() {
                    "☑ "
                } else {
                    "☐ "
                });
            } else if let Some(definition) = tag.definition() {
                output.push_str(&format!("[{}] ", definition.label()));
            }
        }
        if list && !output.starts_with('☐') && !output.starts_with('☑') {
            output.insert_str(0, "• ");
            self.warn("Numbered list labels are normalized to bullets.");
        }
        let mut runs = Vec::new();
        if !output.is_empty() {
            runs.push(json!({"location":0,"length":output.encode_utf16().count(),"format":font_format(base, base)}));
        }
        let utf16: Vec<u16> = text.text().encode_utf16().collect();
        let links = text.hyperlinks();
        let mut boundaries: Vec<usize> = text
            .text_run_indices()
            .iter()
            .map(|v| (*v as usize).min(utf16.len()))
            .collect();
        if boundaries.last().copied() != Some(utf16.len()) {
            boundaries.push(utf16.len());
        }
        let mut start = 0;
        for (index, end) in boundaries.iter().copied().enumerate() {
            if end < start {
                self.warn("Malformed text-run ordering was skipped.");
                continue;
            }
            let style = text.text_run_formatting().get(index).unwrap_or(base);
            if !style.hidden() && end > start {
                let value = String::from_utf16_lossy(&utf16[start..end]);
                let location = output.encode_utf16().count();
                let mut format = font_format(style, base);
                if let Some(link) = links
                    .iter()
                    .find(|l| l.start() as usize <= start && l.end() as usize >= end)
                {
                    if safe_link(link.target()) {
                        format["link"] = json!(link.target());
                    } else {
                        self.warn(
                            "Internal OneNote and non-web links are retained as visible text only.",
                        );
                    }
                }
                runs.push(json!({"location":location,"length":value.encode_utf16().count(),"format":format}));
                output.push_str(&value);
            }
            start = end;
        }
        json!({"text":output,"runs":runs,"defaultFormat":font_format(base, base)})
    }

    fn ink(
        &mut self,
        ink: &Ink,
        elements: &mut Vec<Value>,
        x: f64,
        y: f64,
        depth: usize,
    ) -> Result<()> {
        if depth > 32 {
            return Err(fail("Ink nesting exceeds 32 levels.").into());
        }
        let x = x + units(ink.offset_horizontal(), 0.0);
        let y = y + units(ink.offset_vertical(), 0.0);
        for child in ink.child_groups() {
            self.ink(child, elements, x, y, depth + 1)?;
        }
        let mut paths = Vec::new();
        let mut min_x = f64::INFINITY;
        let mut min_y = f64::INFINITY;
        let mut max_x = f64::NEG_INFINITY;
        let mut max_y = f64::NEG_INFINITY;
        for stroke in ink.ink_strokes() {
            if stroke.path().is_empty() {
                continue;
            }
            self.ink_points = self.ink_points.saturating_add(stroke.path().len());
            if self.ink_points > 2_000_000 {
                return Err(fail("Ink exceeds the two-million-point import limit.").into());
            }
            let mut points = Vec::new();
            for point in stroke.path() {
                // Reader has already applied InkScalingX/Y. ISF ink space uses
                // HIMETRIC (0.01 mm); the native canvas uses 96 units/inch.
                let px = ink_units(point.x());
                let py = ink_units(point.y());
                if !px.is_finite()
                    || !py.is_finite()
                    || px.abs() > 100_000.0
                    || py.abs() > 100_000.0
                {
                    return Err(fail("Invalid or excessively large ink geometry.").into());
                }
                min_x = min_x.min(px);
                min_y = min_y.min(py);
                max_x = max_x.max(px);
                max_y = max_y.max(py);
                points.push((px, py));
            }
            paths.push((stroke, points));
        }
        if paths.is_empty() {
            if ink.child_groups().is_empty() {
                self.warn("An ink container had no decoded stroke points.");
            }
            return Ok(());
        }
        let strokes: Vec<Value> = paths.iter().map(|(stroke, path)| {
            let color = stroke.color().unwrap_or(0x00111111);
            let opacity = 1.0 - f64::from(stroke.transparency().unwrap_or(0)) / 255.0;
            let width = ink_units(stroke.width());
            let width = if width.is_finite() && width > 0.0 { width.clamp(0.25, 288.0) } else { 1.5 };
            let points: Vec<Value> = path.iter().map(|(px, py)| json!({"x":px-min_x,"y":py-min_y,"pressure":1.0})).collect();
            json!({"id":id(),"kind":if opacity < 0.9 {"highlighter"} else {"pen"},
                   "colorHex":format!("#{:02X}{:02X}{:02X}",color & 255,(color >> 8) & 255,(color >> 16) & 255),
                   "width":width,"opacity":opacity,"points":points})
        }).collect();
        self.element(
            elements,
            x + min_x,
            y + min_y,
            max_x - min_x,
            max_y - min_y,
            json!({"type":"ink","strokes":strokes}),
        )?;
        self.warn("Ink is imported as editable vector strokes. Pressure and pen-tip shape are approximated; check scale and positioning, especially nested and inline ink.");
        Ok(())
    }

    fn outline_items(
        &mut self,
        items: &[OutlineItem],
        elements: &mut Vec<Value>,
        x: f64,
        y: &mut f64,
        width: f64,
        depth: usize,
    ) -> Result<()> {
        if depth > 64 {
            return Err(fail("Outline nesting exceeds 64 levels.").into());
        }
        for item in items {
            match item {
                OutlineItem::Group(g) => {
                    self.outline_items(g.outlines(), elements, x, y, width, depth + 1)?
                }
                OutlineItem::Element(e) => {
                    let indent = (e.child_level() as f64).min(20.0) * 18.0;
                    for content in e.contents() {
                        match content {
                            Content::RichText(r) => {
                                let value = self.styled(r, !e.list_contents().is_empty());
                                let w = (width - indent).max(80.0);
                                let font_size = value["runs"]
                                    .as_array()
                                    .unwrap()
                                    .iter()
                                    .filter_map(|run| run["format"]["fontSize"].as_f64())
                                    .fold(14.0, f64::max);
                                let h = text_height(value["text"].as_str().unwrap_or(""), w)
                                    * (font_size / 14.0);
                                let paragraph_y = *y;
                                self.element(
                                    elements,
                                    x + indent,
                                    *y,
                                    w,
                                    h,
                                    json!({"type":"richText","value":value}),
                                )?;
                                *y += h + 6.0;
                                for object in r.embedded_objects() {
                                    if let EmbeddedObject::Ink(container) = object {
                                        self.ink(
                                            container.ink(),
                                            elements,
                                            x + indent,
                                            paragraph_y,
                                            depth + 1,
                                        )?;
                                        self.warn("Inline handwriting is retained as strokes; exact placement within the text line is approximated.");
                                    }
                                }
                            }
                            Content::Image(i) => *y += self.image(i, elements, x + indent, *y)?,
                            Content::EmbeddedFile(f) => {
                                *y += self.attachment(f, elements, x + indent, *y)?
                            }
                            Content::Table(t) => {
                                *y += self.table(
                                    t,
                                    elements,
                                    x + indent,
                                    *y,
                                    width - indent,
                                    depth + 1,
                                )?
                            }
                            Content::Ink(ink) => {
                                self.ink(ink, elements, x + indent, *y, depth + 1)?
                            }
                            Content::Unknown => {
                                self.warn("An unsupported outline object was not converted.")
                            }
                        }
                    }
                    self.outline_items(e.children(), elements, x, y, width, depth + 1)?;
                }
            }
        }
        Ok(())
    }
    fn cell_text(&mut self, element: &OutlineElement, depth: usize) -> Result<String> {
        if depth > 64 {
            return Err(fail("Table nesting exceeds 64 levels.").into());
        }
        let mut text = Vec::new();
        for content in element.contents() {
            match content {
                Content::RichText(r) => text.push(self.rich(r)),
                _ => self.warn("Non-text objects inside table cells were not converted."),
            }
        }
        for item in element.children() {
            if let OutlineItem::Element(child) = item {
                text.push(self.cell_text(child, depth + 1)?);
            } else {
                self.warn("Grouped objects in a table cell were not converted.");
            }
        }
        Ok(text.join("\n"))
    }
    fn table(
        &mut self,
        table: &Table,
        elements: &mut Vec<Value>,
        x: f64,
        y: f64,
        width: f64,
        depth: usize,
    ) -> Result<f64> {
        if table.rows() > 1000
            || table.cols() > 100
            || table.rows().saturating_mul(table.cols()) > 20_000
        {
            return Err(fail("A table exceeds the 20,000-cell limit.").into());
        }
        let mut rows = Vec::new();
        for row in table.contents() {
            let mut cells = Vec::new();
            for cell in row.contents() {
                let mut blocks = Vec::new();
                for e in cell.contents() {
                    blocks.push(self.cell_text(e, depth + 1)?);
                }
                cells.push(blocks.join("\n"));
            }
            rows.push(cells);
        }
        let columns = rows.iter().map(Vec::len).max().unwrap_or(1).max(1);
        if rows.len() > 1000 || columns > 100 || rows.len().saturating_mul(columns) > 20_000 {
            return Err(fail("Actual table contents exceed the 20,000-cell import limit.").into());
        }
        for row in &mut rows {
            row.resize(columns, String::new());
        }
        if rows.is_empty() {
            rows.push(vec![String::new(); columns]);
        }
        let w = width.max(columns as f64 * 120.0);
        let h = rows
            .iter()
            .map(|row| {
                row.iter()
                    .map(|s| text_height(s, w / columns as f64))
                    .fold(32.0, f64::max)
                    + 12.0
            })
            .sum::<f64>();
        self.element(elements, x, y, w, h, json!({"type":"table","rows":rows}))?;
        self.warn("Tables retain text cells; column widths, cell colors and advanced formatting are normalized.");
        Ok(h + 12.0)
    }
    fn section(&mut self, section: &Section, prefix: &str) -> Result<()> {
        for warning in section.report().warnings() {
            self.warn(format!(
                "{}: {}",
                warning
                    .page()
                    .map(|(_, title)| title)
                    .unwrap_or(section.display_name()),
                warning.message()
            ));
        }
        let mut page_ids = Vec::new();
        for series in section.page_series() {
            for page in series.pages() {
                self.page_count += 1;
                if self.page_count > 10_000 {
                    return Err(fail("Import exceeds 10,000 pages.").into());
                }
                let pid = id();
                let mut elements = Vec::new();
                for content in page.contents() {
                    match content {
                        PageContent::Outline(outline) => {
                            let x = units(outline.offset_horizontal(), 48.0).max(0.0);
                            let mut y = units(outline.offset_vertical(), 96.0).max(0.0);
                            let width =
                                units(outline.layout_max_width(), 560.0).clamp(80.0, 100_000.0);
                            self.outline_items(
                                outline.items(),
                                &mut elements,
                                x,
                                &mut y,
                                width,
                                0,
                            )?;
                        }
                        PageContent::Image(i) => {
                            self.image(
                                i,
                                &mut elements,
                                units(i.offset_horizontal(), 48.0),
                                units(i.offset_vertical(), 96.0),
                            )?;
                        }
                        PageContent::EmbeddedFile(f) => {
                            self.attachment(
                                f,
                                &mut elements,
                                units(f.offset_horizontal(), 48.0),
                                units(f.offset_vertical(), 96.0),
                            )?;
                        }
                        PageContent::Ink(ink) => self.ink(ink, &mut elements, 0.0, 0.0, 0)?,
                        PageContent::Unknown => {
                            self.warn("An unsupported page object was not converted.")
                        }
                    }
                }
                let title = page
                    .title_text()
                    .filter(|s| !s.trim().is_empty())
                    .unwrap_or("Untitled page");
                let value = json!({"id":pid,"title":title,"createdAt":date(page.created_time()),"modifiedAt":date(page.updated_time()),"level":page.level().clamp(0,2),"background":"plain","elements":elements});
                fs::write(
                    self.output.join("pages").join(format!("{pid}.json")),
                    serde_json::to_vec_pretty(&value)?,
                )?;
                page_ids.push(pid);
            }
        }
        let color = section
            .color()
            .map(|c| format!("#{:02X}{:02X}{:02X}", c.r(), c.g(), c.b()))
            .unwrap_or("#3B82F6".into());
        self.sections.push(json!({"id":id(),"name":format!("{prefix}{}",section.display_name()),"colorHex":color,"pageIDs":page_ids}));
        Ok(())
    }
    fn entries(&mut self, entries: &[SectionEntry], prefix: &str, depth: usize) -> Result<()> {
        if depth > 32 {
            return Err(fail("Section group nesting exceeds 32 levels.").into());
        }
        for entry in entries {
            match entry {
                SectionEntry::Section(s) => self.section(s, prefix)?,
                SectionEntry::SectionGroup(g) => {
                    self.warn(
                        "Section groups are flattened into section names with their group path.",
                    );
                    self.entries(
                        g.entries(),
                        &format!("{prefix}{} / ", g.display_name()),
                        depth + 1,
                    )?;
                }
            }
        }
        Ok(())
    }
}
fn units(value: Option<f32>, fallback: f64) -> f64 {
    value
        .filter(|v| v.is_finite())
        .map(|v| v as f64 * 48.0)
        .unwrap_or(fallback)
}
fn text_height(text: &str, width: f64) -> f64 {
    text.lines()
        .map(|line| {
            (line.chars().count() as f64 / (width / 7.0).max(1.0))
                .ceil()
                .max(1.0)
        })
        .sum::<f64>()
        .max(1.0)
        * 20.0
        + 16.0
}
fn escape_markdown(text: &str) -> String {
    let mut out = String::new();
    for ch in text.chars() {
        if "\\`*_[]<>".contains(ch) {
            out.push('\\');
        }
        out.push(ch);
    }
    out
}
fn ink_units(value: f32) -> f64 {
    f64::from(value) * 96.0 / 2540.0
}
fn font_format(style: &ParagraphStyling, base: &ParagraphStyling) -> Value {
    use onenote_parser::property::common::ColorRef;
    let color = match style.font_color().or(base.font_color()) {
        Some(ColorRef::Manual { r, g, b }) => format!("#{r:02X}{g:02X}{b:02X}"),
        _ => "#111111".into(),
    };
    json!({"fontName":style.font().or(base.font()).filter(|s| !s.trim().is_empty()).unwrap_or("Helvetica"),
           "fontSize":(f64::from(style.font_size().or(base.font_size()).unwrap_or(28)) / 2.0).clamp(6.0,288.0),
           "bold":style.bold(),"italic":style.italic(),"underline":style.underline(),"colorHex":color})
}

fn safe_link(target: &str) -> bool {
    ["https://", "http://", "mailto:"]
        .iter()
        .any(|p| target.to_ascii_lowercase().starts_with(p))
}
fn date(t: time::UtcDateTime) -> String {
    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z",
        t.year(),
        u8::from(t.month()),
        t.day(),
        t.hour(),
        t.minute(),
        t.second()
    )
}
fn check_package(path: &Path) -> Result<()> {
    let cabinet = cab::Cabinet::new(fs::File::open(path)?)?;
    let mut total = 0u64;
    let mut count = 0usize;
    for folder in cabinet.folder_entries() {
        for file in folder.file_entries() {
            total = total.saturating_add(file.uncompressed_size() as u64);
            count += 1;
            if file.uncompressed_size() as u64 > MAX_FILE || total > MAX_TOTAL || count > 20_000 {
                return Err(fail("The package exceeds the expanded-size import limit.").into());
            }
        }
    }
    Ok(())
}
fn run(input: &Path, output: &Path) -> Result<()> {
    let input = input.canonicalize()?;
    if !input.is_file() || fs::metadata(&input)?.len() > MAX_FILE {
        return Err(fail("Choose a regular OneNote file no larger than 256 MB.").into());
    }
    if output.exists() {
        return Err(fail("The output already exists; no files were changed.").into());
    }
    let extension = input
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or(if input.file_name().is_some_and(|s| s == ".onetoc2") {
            "onetoc2"
        } else {
            ""
        })
        .to_ascii_lowercase();
    if !["one", "onetoc2", "onepkg"].contains(&extension.as_str()) {
        return Err(fail("Choose a .one, .onetoc2 or .onepkg file.").into());
    }
    if extension == "onepkg" {
        check_package(&input)?;
    }
    fs::create_dir(output)?;
    fs::create_dir(output.join("pages"))?;
    fs::create_dir(output.join("media"))?;
    let bytes = AtomicU64::new(0);
    let issues = Mutex::new(Vec::new());
    let confined = ConfinedFs {
        root: input
            .parent()
            .ok_or_else(|| fail("Missing source directory."))?,
        read_bytes: &bytes,
        issues: &issues,
    };
    let parser = Parser::new_with_fs(confined);
    let path = TypedPath::derive(
        input
            .to_str()
            .ok_or_else(|| fail("Non-UTF-8 source path."))?,
    );
    let mut c = Converter {
        output: output.into(),
        sections: Vec::new(),
        warnings: Vec::new(),
        page_count: 0,
        element_count: 0,
        media_bytes: 0,
        media_count: 0,
        ink_points: 0,
    };
    if extension == "one" {
        c.section(&parser.parse_section(path)?, "")?;
    } else {
        let notebook = if extension == "onepkg" {
            parser.parse_package(path)?
        } else {
            parser.parse_notebook(path)?
        };
        for warning in notebook.report().warnings() {
            c.warn(warning.message());
        }
        c.entries(notebook.entries(), "", 0)?;
    }
    if c.page_count == 0 {
        return Err(fail("No readable pages were found; nothing was imported.").into());
    }
    for issue in issues
        .lock()
        .map_err(|_| fail("Import diagnostics lock failed."))?
        .iter()
    {
        c.warn(issue.clone());
    }
    c.warn("Outline positions are retained where available; paragraph heights and nested layout are approximated. Review section and page counts after notebook/package import.");
    c.warn("This imports current pages, not revision history, recycle-bin items, password-protected sections or live synchronization. Keep your source files.");
    let manifest = json!({"format":"org.opennotebook.notebook","schemaVersion":3,"id":id(),"name":input.file_stem().and_then(|s|s.to_str()).unwrap_or("Imported Notebook"),"sections":c.sections});
    fs::write(
        output.join("manifest.json"),
        serde_json::to_vec_pretty(&manifest)?,
    )?;
    let report = json!({"sourceFile":input.file_name().and_then(|s|s.to_str()),"parser":"onenote_parser 2.0.0 (MPL-2.0)","pages":c.page_count,"sections":manifest["sections"].as_array().map(Vec::len),"elements":c.element_count,"attachments":c.media_count,"warnings":c.warnings});
    fs::write(
        output.join("import-report.json"),
        serde_json::to_vec_pretty(&report)?,
    )?;
    println!(
        "Imported {} pages, {} attachments.",
        c.page_count, c.media_count
    );
    Ok(())
}
fn main() {
    let args: Vec<_> = std::env::args_os().collect();
    if args.len() != 3 {
        eprintln!("Usage: one-import INPUT.one|INPUT.onetoc2|INPUT.onepkg NEW_OUTPUT.onbook");
        std::process::exit(2);
    }
    if let Err(error) = run(Path::new(&args[1]), Path::new(&args[2])) {
        eprintln!("Import failed: {error}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn half_inch_units_and_missing_layout() {
        assert_eq!(units(Some(2.0), 9.0), 96.0);
        assert_eq!(units(Some(f32::NAN), 9.0), 9.0);
    }
    #[test]
    fn ink_himetric_to_canvas_and_pen_width() {
        assert!((ink_units(2540.0) - 96.0).abs() < 1e-9);
        assert!((ink_units(50.0) - 1.8897637795).abs() < 1e-9);
        assert!(ink_units(f32::NAN).is_nan());
    }
    #[test]
    fn markdown_keeps_literal_markers() {
        assert_eq!(escape_markdown("hello *[x]* 😀"), "hello \\*\\[x\\]\\* 😀");
    }
    #[test]
    fn external_link_allowlist() {
        assert!(safe_link("https://example.org"));
        assert!(!safe_link("file:///etc/passwd"));
        assert!(!safe_link("onenote:test"));
    }
    #[test]
    fn refuses_existing_output() {
        let base = std::env::temp_dir().join(id());
        fs::create_dir(&base).unwrap();
        let input = base.join("test.one");
        fs::write(&input, b"invalid").unwrap();
        assert!(run(&input, &base)
            .unwrap_err()
            .to_string()
            .contains("already exists"));
        assert_eq!(fs::read(&input).unwrap(), b"invalid");
        fs::remove_dir_all(base).unwrap();
    }
    #[test]
    fn confines_symlink_references() {
        let base = std::env::temp_dir().join(id());
        fs::create_dir(&base).unwrap();
        let total = AtomicU64::new(0);
        let issues = Mutex::new(Vec::new());
        let confined = ConfinedFs {
            root: &base,
            read_bytes: &total,
            issues: &issues,
        };
        assert!(confined.resolve(TypedPath::derive("/etc/passwd")).is_err());
        fs::remove_dir_all(base).unwrap();
    }
}
