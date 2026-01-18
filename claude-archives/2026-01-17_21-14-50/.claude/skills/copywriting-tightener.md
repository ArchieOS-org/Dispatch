# Copywriting Tightener

## Purpose
Ensure all user-facing text is clear, concise, and matches Apple's communication style.

## When to Run
- Any new user-facing strings (labels, buttons, messages, alerts)
- Error messages or confirmation dialogs
- Onboarding or instructional text

## Steps (Max 10)
1. **Cut ruthlessly**: Can any words be removed without losing meaning?
2. **Active voice**: Rewrite passive constructions ("was saved" -> "Saved")
3. **Front-load action**: Buttons should start with verbs ("Add Item", not "Item Addition")
4. **No jargon**: Replace technical terms with plain language
5. **Consistent terminology**: Use the same word for the same concept throughout
6. **Sentence case**: Use sentence case for buttons/labels (not Title Case or ALL CAPS)
7. **No exclamation marks**: Professional, calm tone (except for celebration states)
8. **Error messages**: Be helpful, not blaming ("Check your connection" not "Network error")
9. **Character limits**: Verify text doesn't truncate on small screens
10. **Localization ready**: No concatenated strings, no embedded punctuation

## Output Format
```
COPYWRITING: [PASS | FAIL]

Strings reviewed: [count]

Checked:
- [ ] Conciseness: [status]
- [ ] Active voice: [status]
- [ ] Consistent terms: [status]
- [ ] Sentence case: [status]
- [ ] Error tone: [status]

Suggestions (if any):
- "[original]" -> "[improved]"
```
