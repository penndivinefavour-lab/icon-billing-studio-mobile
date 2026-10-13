from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
import os
import re

md_path = r'docs/FINAL_RELEASE_ACCEPTANCE_REPORT.md'
pdf_path = r'docs/FINAL_RELEASE_ACCEPTANCE_REPORT.pdf'

doc = SimpleDocTemplate(
    pdf_path,
    pagesize=letter,
    rightMargin=36,
    leftMargin=36,
    topMargin=36,
    bottomMargin=36
)

styles = getSampleStyleSheet()

title_style = ParagraphStyle(
    'ReportTitle',
    parent=styles['Heading1'],
    fontSize=14,
    leading=18,
    spaceAfter=6,
    textColor=colors.HexColor('#1E1B4B')
)

h2_style = ParagraphStyle(
    'ReportH2',
    parent=styles['Heading2'],
    fontSize=11,
    leading=14,
    spaceBefore=8,
    spaceAfter=3,
    textColor=colors.HexColor('#1E1B4B')
)

h3_style = ParagraphStyle(
    'ReportH3',
    parent=styles['Heading3'],
    fontSize=9,
    leading=12,
    spaceBefore=6,
    spaceAfter=2,
    textColor=colors.HexColor('#334155')
)

body_style = ParagraphStyle(
    'ReportBody',
    parent=styles['Normal'],
    fontSize=8,
    leading=10.5,
    spaceAfter=3,
    textColor=colors.HexColor('#1E293B')
)

bullet_style = ParagraphStyle(
    'ReportBullet',
    parent=styles['Normal'],
    fontSize=8,
    leading=10.5,
    leftIndent=10,
    spaceAfter=2,
    textColor=colors.HexColor('#1E293B')
)

code_style = ParagraphStyle(
    'ReportCode',
    parent=styles['Code'],
    fontSize=7,
    leading=9,
    leftIndent=10,
    spaceAfter=3,
    textColor=colors.HexColor('#0F172A')
)

table_cell_style = ParagraphStyle(
    'TableCell',
    parent=styles['Normal'],
    fontSize=7,
    leading=9,
    textColor=colors.HexColor('#1E293B')
)

table_header_style = ParagraphStyle(
    'TableHeader',
    parent=styles['Normal'],
    fontSize=7.5,
    leading=9.5,
    fontName='Helvetica-Bold',
    textColor=colors.white
)

def escape_xml(text):
    text = text.replace('&', '&amp;')
    text = text.replace('<', '&lt;')
    text = text.replace('>', '&gt;')
    # handle bold **text**
    text = re.sub(r'\*\*(.*?)\*\*', r'<b>\1</b>', text)
    # handle `code`
    text = re.sub(r'`(.*?)`', r'<font face="Courier">\1</font>', text)
    # handle *italic*
    text = re.sub(r'\*(.*?)\*', r'<i>\1</i>', text)
    return text

story = []

with open(md_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

table_lines = []
in_table = False
in_code = False
code_lines = []

def process_table(tbl_lines):
    rows = []
    for line in tbl_lines:
        line_clean = line.strip().strip('|')
        if not line_clean or '---' in line_clean:
            continue
        cols = [c.strip() for c in line.split('|')[1:-1]]
        if cols:
            rows.append(cols)
    if not rows:
        return None
    
    col_count = len(rows[0])
    avail_width = 540  # 612 - 72 margins
    
    if col_count == 2:
        col_widths = [140, 400]
    elif col_count == 4:
        col_widths = [100, 140, 200, 100]
    elif col_count == 5:
        col_widths = [75, 110, 115, 80, 160]
    else:
        col_widths = [avail_width / col_count] * col_count

    table_data = []
    for i, row in enumerate(rows):
        row_cells = []
        is_hdr = (i == 0)
        st = table_header_style if is_hdr else table_cell_style
        for c in row:
            row_cells.append(Paragraph(escape_xml(c), st))
        table_data.append(row_cells)

    tbl = Table(table_data, colWidths=col_widths, repeatRows=1)
    tbl.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1E1B4B')),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 4),
        ('TOPPADDING', (0, 0), (-1, 0), 4),
        ('BOTTOMPADDING', (0, 1), (-1, -1), 3),
        ('TOPPADDING', (0, 1), (-1, -1), 3),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F8FAFC')]),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
    ]))
    return tbl

for line in lines:
    line_str = line.strip()
    
    # Handle code block toggle
    if line_str.startswith('```'):
        if in_code:
            in_code = False
            code_text = "<br/>".join(code_lines)
            story.append(Paragraph(code_text, code_style))
            story.append(Spacer(1, 3))
            code_lines = []
        else:
            in_code = True
            code_lines = []
        continue
        
    if in_code:
        code_lines.append(escape_xml(line.rstrip()))
        continue
        
    # Handle tables
    if line_str.startswith('|'):
        if not in_table:
            in_table = True
            table_lines = [line]
        else:
            table_lines.append(line)
        continue
    else:
        if in_table:
            in_table = False
            tbl = process_table(table_lines)
            if tbl:
                story.append(tbl)
                story.append(Spacer(1, 4))
            table_lines = []

    if not line_str:
        story.append(Spacer(1, 2))
        continue

    if line_str == '---':
        story.append(Spacer(1, 3))
        continue

    if line_str.startswith('# '):
        story.append(Paragraph(escape_xml(line_str[2:]), title_style))
    elif line_str.startswith('## '):
        story.append(Paragraph(escape_xml(line_str[3:]), h2_style))
    elif line_str.startswith('### '):
        story.append(Paragraph(escape_xml(line_str[4:]), h3_style))
    elif line_str.startswith('- ') or line_str.startswith('* '):
        story.append(Paragraph('&bull; ' + escape_xml(line_str[2:]), bullet_style))
    elif re.match(r'^\d+\.\s', line_str):
        num_prefix = re.match(r'^\d+\.\s', line_str).group(0)
        content = line_str[len(num_prefix):]
        story.append(Paragraph(f'<b>{num_prefix}</b>' + escape_xml(content), bullet_style))
    else:
        story.append(Paragraph(escape_xml(line_str), body_style))

# If table at end of file
if in_table and table_lines:
    tbl = process_table(table_lines)
    if tbl:
        story.append(tbl)

doc.build(story)
print(f"Generated {pdf_path} successfully. Size: {os.path.getsize(pdf_path)} bytes")
