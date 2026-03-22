# Ravago Corporate Document Template

## Overview

This skill defines the **exact** Ravago corporate template used for official documents. Every Word document created for Ravago MUST follow these specifications precisely.

## Color Palette

**Primary Blue (Ravago Blue):** `#0245AE` (RGB: 2, 69, 174)
- This exact blue is used throughout the template

## Fonts

**Default Font:** Calibri (majorHAnsi theme font)
**Heading Font:** Calibri
**Footer/Header Font:** Arial

## Page Setup

- **Page Size:** A4 (11906 x 16838 DXA) - European standard
- **Margins:** Standard 1 inch (1440 DXA) all around
- **Orientation:** Portrait

## Header Structure

The header contains:

1. **Blue Horizontal Bar:**
   - Full-width horizontal bar at the top of the page
   - Color: Ravago Blue (#0245AE)
   - Height: Approximately 0.5 inches
   - Positioned at the very top of the page

2. **Ravago Logo:**
   - Positioned: Top-right corner of the header
   - Behind the blue bar (overlapping)
   - Logo image should be embedded from `/home/claude/ravago_logo.jpeg`
   - Image is anchored to the right side of the page
   - The logo is the white "Ravago" text with stylized building/blocks design

## Document Title

The document title appears below the header section:

- **Font:** Calibri (majorHAnsi)
- **Color:** Ravago Blue (#0245AE)
- **Size:** 22pt (44 half-points in Word XML)
- **Style:** Bold
- **Spacing:** 4 blank lines above the title (empty paragraphs with same formatting)
- **Position:** Left-aligned

## Classification Text

Below the blue bar header, include the classification:
- **Text:** "Internal use only"
- **Color:** Light gray or subtle color
- **Position:** Top-left or as appropriate

## Heading Styles

### Heading 1
- **Font:** Calibri (majorHAnsi)
- **Color:** Ravago Blue (#0245AE)
- **Size:** 14pt (28 half-points)
- **Style:** Bold
- **Numbering:** Automatic numbering enabled (1, 2, 3, etc.)
- **Spacing Before:** 480 twips (approximately 24pt)
- **Spacing After:** 0
- **Keep With Next:** Yes
- **Keep Lines Together:** Yes
- **Outline Level:** 0

### Heading 2
- **Font:** Calibri (majorHAnsi)
- **Color:** Black or Ravago Blue (verify per document)
- **Size:** 13pt (26 half-points)
- **Style:** Bold
- **Numbering:** Automatic sub-numbering (1.1, 1.2, etc.)
- **Outline Level:** 1

## Footer Structure

The footer is complex and contains multiple elements:

### Left Side Footer Content:
- **Text:** Department name in blue (#0245AE), Arial 10pt, bold
  - Example: "Information Security"
- **Text:** Version number in blue (#0245AE), Arial 10pt, bold
  - Example: "Version 1.0"
- **Text:** Page numbering in Arial 10pt
  - Format: "Page [PAGE_NUMBER]"

### Right Side Footer - Vertical Blue Sidebar:
- **Blue Vertical Bar:**
  - Full height on the right edge of the page
  - Width: Approximately 0.75-1 inch
  - Color: Ravago Blue (#0245AE)
  - Positioned at absolute right edge

- **Vertical Text on Blue Bar:**
  - Text: Document classification (e.g., "Group Procedure")
  - Font: Arial or Calibri
  - Color: White (#FFFFFF)
  - Size: 20pt (40 half-points)
  - Style: Bold
  - Rotation: 90 degrees (vertical, reading from bottom to top)
  - This is created using a text box with rotation

## Body Text

- **Font:** Calibri 11pt (22 half-points)
- **Color:** Black
- **Line Spacing:** Multiple 1.15 or as appropriate
- **Paragraph Spacing:** Default Word spacing

## Lists and Bullets

- Use proper Word numbering/bullet formatting
- **NEVER** use unicode bullet characters
- Indent appropriately with Word's built-in list features

## Implementation in docx-js

When creating documents with JavaScript/docx-js, use these exact specifications:

```javascript
const { Document, Packer, Paragraph, TextRun, Header, Footer, ImageRun,
        AlignmentType, LevelFormat, WidthType, BorderStyle } = require('docx');
const fs = require('fs');

// Ravago Blue color constant
const RAVAGO_BLUE = "0245AE";

// Create document with Ravago template
const doc = new Document({
  styles: {
    default: { 
      document: { 
        run: { font: "Calibri", size: 22 } // 11pt default
      } 
    },
    paragraphStyles: [
      { 
        id: "Heading1", 
        name: "Heading 1", 
        basedOn: "Normal", 
        next: "Normal", 
        quickFormat: true,
        run: { 
          size: 28,        // 14pt
          bold: true, 
          font: "Calibri",
          color: RAVAGO_BLUE 
        },
        paragraph: { 
          spacing: { before: 480, after: 0 },
          keepNext: true,
          keepLines: true,
          outlineLevel: 0 
        } 
      },
      { 
        id: "Heading2", 
        name: "Heading 2", 
        basedOn: "Normal", 
        next: "Normal", 
        quickFormat: true,
        run: { 
          size: 26,        // 13pt
          bold: true, 
          font: "Calibri",
          color: RAVAGO_BLUE 
        },
        paragraph: { 
          spacing: { before: 360, after: 0 },
          outlineLevel: 1 
        } 
      }
    ]
  },
  
  numbering: {
    config: [
      {
        reference: "heading-numbering",
        levels: [
          { 
            level: 0, 
            format: LevelFormat.DECIMAL, 
            text: "%1", 
            alignment: AlignmentType.LEFT,
            style: { 
              paragraph: { 
                indent: { left: 567, hanging: 567 } 
              } 
            } 
          },
          { 
            level: 1, 
            format: LevelFormat.DECIMAL, 
            text: "%1.%2", 
            alignment: AlignmentType.LEFT,
            style: { 
              paragraph: { 
                indent: { left: 1134, hanging: 567 } 
              } 
            } 
          }
        ]
      }
    ]
  },
  
  sections: [{
    properties: {
      page: {
        size: {
          width: 11906,   // A4 width
          height: 16838   // A4 height
        },
        margin: { 
          top: 1440,      // 1 inch
          right: 1440, 
          bottom: 1440, 
          left: 1440 
        }
      }
    },
    
    headers: {
      default: new Header({
        children: [
          // Blue horizontal bar - use paragraph with bottom border
          new Paragraph({
            children: [new TextRun("")],
            border: {
              bottom: {
                color: RAVAGO_BLUE,
                space: 1,
                style: BorderStyle.SINGLE,
                size: 36  // Thick border to create bar effect
              }
            },
            spacing: { after: 0 }
          }),
          
          // Ravago logo would be added here as ImageRun
          // positioned to top-right
          // Logo: ravago_logo.jpeg from /home/claude/
        ]
      })
    },
    
    footers: {
      default: new Footer({
        children: [
          // Department name
          new Paragraph({
            alignment: AlignmentType.RIGHT,
            children: [
              new TextRun({
                text: "Information Security",
                font: "Arial",
                size: 20,  // 10pt
                bold: true,
                color: RAVAGO_BLUE
              })
            ]
          }),
          
          // Version number
          new Paragraph({
            alignment: AlignmentType.RIGHT,
            children: [
              new TextRun({
                text: "Version 1.0",
                font: "Arial",
                size: 20,
                bold: true,
                color: RAVAGO_BLUE
              })
            ]
          }),
          
          // Page number
          new Paragraph({
            alignment: AlignmentType.RIGHT,
            children: [
              new TextRun({
                text: "Page ",
                font: "Arial",
                size: 20
              }),
              // PAGE field would be added here
            ]
          }),
          
          // Note: Vertical blue sidebar with rotated text
          // This requires a text box which is complex in docx-js
          // Best approach: create via XML editing after initial creation
        ]
      })
    },
    
    children: [
      // 4 empty paragraphs for spacing (blue color, 22pt, bold)
      new Paragraph({
        children: [new TextRun("")],
        run: { size: 44, bold: true, color: RAVAGO_BLUE }
      }),
      new Paragraph({
        children: [new TextRun("")],
        run: { size: 44, bold: true, color: RAVAGO_BLUE }
      }),
      new Paragraph({
        children: [new TextRun("")],
        run: { size: 44, bold: true, color: RAVAGO_BLUE }
      }),
      new Paragraph({
        children: [new TextRun("")],
        run: { size: 44, bold: true, color: RAVAGO_BLUE }
      }),
      
      // Document title
      new Paragraph({
        children: [
          new TextRun({
            text: "Document Title Here",
            font: "Calibri",
            size: 44,      // 22pt
            bold: true,
            color: RAVAGO_BLUE
          })
        ]
      }),
      
      // Content continues...
    ]
  }]
});

// Save the document
Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync("ravago_document.docx", buffer);
});
```

## Key Visual Elements Summary

1. **Top horizontal blue bar** spanning the full width
2. **Ravago logo** in top-right corner (overlapping the blue bar)
3. **Document title** in Ravago Blue, 22pt, bold, with 4 blank lines above
4. **Blue Heading 1** text with automatic numbering
5. **Footer** with department name, version, and page number in blue
6. **Vertical blue sidebar** on the right edge with rotated white text

## Critical Requirements

- **Color consistency:** ALWAYS use #0245AE for Ravago Blue
- **Font consistency:** Calibri for body/headings, Arial for footer
- **Logo placement:** Top-right corner, overlapping the blue header bar
- **Vertical sidebar:** Right edge with rotated text reading bottom-to-top
- **Classification:** "Internal use only" must appear appropriately

## Files Reference

- **Ravago Logo:** `/home/claude/ravago_logo.jpeg` (1344x1901 pixels)
- **Template Source:** Original document unpacked at `/home/claude/unpacked_ravago/`

## XML-Based Implementation Notes

For complex elements like the vertical sidebar, it's easier to:
1. Create the base document with docx-js
2. Unpack the .docx
3. Edit the footer2.xml to add the vertical text box with rotation
4. Pack the document back

The vertical sidebar is created using a `<wps:wsp>` shape with `rot="16200000"` (90 degrees) containing white text on a transparent/no-fill background, positioned absolutely on the right side of the footer.

## Template Validation Checklist

Before finalizing any Ravago document, verify:

- [ ] Blue horizontal bar at top (#0245AE)
- [ ] Ravago logo in top-right corner
- [ ] Document title is blue (#0245AE), 22pt, bold
- [ ] Headings are blue (#0245AE), 14pt, bold with numbering
- [ ] Footer has department name in blue
- [ ] Footer has version number in blue  
- [ ] Footer has page numbers
- [ ] Vertical blue sidebar on right with rotated white text
- [ ] "Internal use only" classification present
- [ ] Font is Calibri for body/headings
- [ ] Font is Arial for footer text

---

**Last Updated:** March 20, 2026
**Source Document:** SEC-Ravago_Group_Patch_Management_Procedure.docx
