function bold() { wrapWith("**") }
function italic() { wrapWith("*") }
function strikethrough() { wrapWith("~~") }
function h1() { toggleFormat("#", 1) }
function h2() { toggleFormat("#", 2) }
function h3() { toggleFormat("#", 3) }
function h4() { toggleFormat("#", 4) }
function h5() { toggleFormat("#", 5) }
function h6() { toggleFormat("#", 6) }
function blockquote() { toggleFormat(">") }
function code() { wrapWith("`") }
function codeblock() { wrapWith("```", true) }
function ul() { list("unordered") }
function li() { list("ordered") }
function image() { document.getElementById('file').click() }

function wrapWith(chars, newLine = false) {
  const textAreaTarget = document.getElementById('content');
  const start = textAreaTarget.selectionStart;
  const end = textAreaTarget.selectionEnd;
  const text = textAreaTarget.value;
  const selectedText = text.substring(start, end);

  // Check if selection is already bold
  const beforeSelection = text.substring(start - chars.length, start);
  const afterSelection = text.substring(end, end + chars.length);
  const isBold = beforeSelection === chars && afterSelection === chars;

  if (isBold) {
    // Remove bold formatting
    textAreaTarget.value = text.substring(0, start - chars.length) +
                        selectedText +
                        text.substring(end + chars.length);

    // Adjust cursor position
    textAreaTarget.setSelectionRange(start - chars.length, end - chars.length);
  } else {
    // Add bold formatting
    const additionalChars = newLine ? "\n" : "";
    textAreaTarget.value = text.substring(0, start) +
                        chars + additionalChars + selectedText + additionalChars + chars +
                        text.substring(end);

    const additionalCharsLength = newLine ? 1 : 0;
    // Adjust cursor position
    if (start === end) {
      // If no text is selected, place cursor between asterisks
      textAreaTarget.setSelectionRange(start + chars.length + additionalCharsLength, end + chars.length + additionalCharsLength);
    } else {
      // If text is selected, select the text including asterisks
      textAreaTarget.setSelectionRange(start, end + (chars.length * 2));
    }
  }

  textAreaTarget.focus()
}

function toggleFormat(char, level = 1) {
  const textAreaTarget = document.getElementById('content');
  const text = textAreaTarget.value;
  const start = textAreaTarget.selectionStart;
  const end = textAreaTarget.selectionEnd;

  // Get the start and end of the current line
  const beforeText = text.substring(0, start);
  const afterText = text.substring(end);
  const lineStart = beforeText.lastIndexOf('\n') + 1;
  const lineEnd = text.indexOf('\n', end);
  const currentLine = text.substring(
    lineStart,
    lineEnd === -1 ? text.length : lineEnd
  );

  // Check if line already has a heading
  const currentHeadingMatch = currentLine.match(/^(#{1,6})\s/);
  const headingMarker = char.repeat(level) + ' ';

  let newLine;
  if (currentHeadingMatch) {
    if (currentHeadingMatch[1].length === level) {
      // Remove heading if same level
      newLine = currentLine.substring(currentHeadingMatch[0].length);
    } else {
      // Change heading level
        newLine = headingMarker + currentLine.substring(currentHeadingMatch[0].length);
    }
  } else {
    // Add new heading
    newLine = headingMarker + currentLine;
  }

  // Calculate new cursor position
  const beforeLength = beforeText.length - lineStart;
  const newCursorPos = lineStart + beforeLength;

  // Update textAreaTarget content
  textAreaTarget.value = text.substring(0, lineStart) +
                      newLine +
                      (lineEnd === -1 ? '' : text.substring(lineEnd));

  // Restore cursor position
  textAreaTarget.setSelectionRange(newCursorPos + level + 1, newCursorPos + level + 1);
  textAreaTarget.focus();
}

function anchor() {
  const textAreaTarget = document.getElementById('content');
  const text = textAreaTarget.value;
  const start = textAreaTarget.selectionStart;
  const end = textAreaTarget.selectionEnd;
  const selectedText = text.substring(start, end);

  // Check if the selection is already a Markdown link
  const linkRegex = /\[(.*?)\]\((.*?)\)/;
  const isLink = linkRegex.test(selectedText);

  if (isLink) {
    // If it's already a link, remove the link formatting
    const matches = selectedText.match(linkRegex);
    const linkText = matches[1];
    textAreaTarget.value = text.substring(0, start) + linkText + text.substring(end);
    textAreaTarget.setSelectionRange(start, start + linkText.length);
  } else {
    // Create new link with empty parentheses
    const linkText = selectedText || 'link text';
    const markdownLink = `[${linkText}]()`;

    textAreaTarget.value =
        text.substring(0, start) +
        markdownLink +
        text.substring(end);

    if (!selectedText) {
      // Select the default "link text" if no text was selected
      textAreaTarget.setSelectionRange(start + 1, start + 10);
    } else {
      // Place cursor between the parentheses
      const cursorPos = start + selectedText.length + 3;
      textAreaTarget.setSelectionRange(cursorPos, cursorPos);
    }
  }

  textAreaTarget.focus();
}

function handleEnterKey() {
  const textAreaTarget = document.getElementById('content');
  const textArea = textAreaTarget;
  const start = textArea.selectionStart;
  const text = textArea.value;
  console.log(JSON.stringify(text))

  // Find the current line
  const beforeCursor = text.substring(0, start);
  const lineStartIndex = beforeCursor.lastIndexOf('\n') + 1;
  const currentLine = text.substring(lineStartIndex, start);

  // Check for unordered or ordered list patterns
  const unorderedMatch = currentLine.trim().match(/^(-\s*)(.*)$/);
  const orderedMatch = currentLine.trim().match(/^(\d+\.\s*)(.*)$/);

  if (unorderedMatch || orderedMatch) {
    const listPrefix = unorderedMatch
      ? unorderedMatch[1]
      : orderedMatch[1];
    const lineContent = unorderedMatch
      ? unorderedMatch[2]
      : orderedMatch[2];

    // If current list item is empty, remove list formatting
    if (lineContent.trim() === '') {
      const newText =
        text.substring(0, lineStartIndex) +
        text.substring(start);

      textArea.value = newText;
      textArea.setSelectionRange(lineStartIndex, lineStartIndex);
      return;
    }

    // Prepare next list prefix
    let nextListPrefix = listPrefix;
    if (orderedMatch) {
      const currentNumber = parseInt(orderedMatch[1]);
      nextListPrefix = `${currentNumber + 1}. `;
    }

    // Insert new list item
    const newText =
      beforeCursor +
      "\n" +
      nextListPrefix +
      text.substring(start);

    textArea.value = newText;

    // Set cursor position right after the list prefix
    const newCursorPosition = start + nextListPrefix.length + 1;
    setTimeout(() => {
      textArea.setSelectionRange(newCursorPosition, newCursorPosition);
    })
  }
}

function list(listType) {
  const textAreaTarget = document.getElementById('content');
  const textArea = textAreaTarget
  let start = textArea.selectionStart;
  let end = textArea.selectionEnd;

  // Get the current text content
  const text = textArea.value;

  // Check if no text is selected
  if (start === end) {
    // Find the current line
    let beforeCursor = text.substring(0, start);
    const afterCursor = text.substring(end);
    const lineStartIndex = beforeCursor.lastIndexOf('\n') + 1;
    const currentLine = text.substring(lineStartIndex, start);
    beforeCursor = beforeCursor.substring(0, lineStartIndex - 1);

    // Determine the list marker based on type
    const listMarker = listType === 'ordered' ? '1. ' : '- ';

    // If the current line is already a list item, exit
    if (currentLine.trim().startsWith('- ') || currentLine.trim().match(/^\d+\.\s/)) {
      return;
    }

    // Insert new list item
    const newLine = beforeCursor == "" ? "" : "\n"
    const newText = beforeCursor + newLine  + listMarker + currentLine + afterCursor;

    // Update the textarea
    textArea.value = newText;

    // Move cursor after the list marker
    const newCursorPosition = start + listMarker.length;
    textArea.setSelectionRange(newCursorPosition, newCursorPosition);

    // Focus back on the textarea
    textArea.focus();
    return;
  }

  // If text is selected, use previous list formatting logic
  const selectedText = text.substring(start, end);

  // Split the selected text into lines
  const lines = selectedText.split('\n');

  // Prepare the formatted lines based on list type
  const formattedLines = lines.map((line, index) => {
    // Trim whitespace to ensure consistent formatting
    const trimmedLine = line.trim();

    if (listType === 'ordered') {
      // For ordered lists, use the line number
      return `${index + 1}. ${trimmedLine}`;
    } else {
      // For unordered lists, use a hyphen
      return `- ${trimmedLine}`;
    }
  });

  // Join the formatted lines
  const formattedText = formattedLines.join('\n');

  // Replace the selected text with formatted text
  const newText =
    text.substring(0, start) +
    formattedText +
    text.substring(end);

  // Update the textarea
  textArea.value = newText;

  // Optionally, set the selection to the newly formatted text
  textArea.setSelectionRange(start, start + formattedText.length);

  // Focus back on the textarea
  textArea.focus();
}

document.addEventListener('DOMContentLoaded', function() {
  const toolbar = document.getElementById('toolbar');
  const buttons = toolbar.getElementsByTagName('button');
  const textArea = document.getElementById('content');

  textArea.addEventListener('keydown', function(event) {
    if (event.key === 'Enter') {
      handleEnterKey();
    }
  })

  for (const button of buttons) {
    button.addEventListener('click', function(event) {
      event.preventDefault();
    });
  }
})
