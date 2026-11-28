# Fix file template (fix-N.md)

Send with `pi-run.sh -r ... fix-N.md` so pi keeps the context of the original task.
Escalate detail each round: symptom, then expected behavior, then exact code.

```markdown
# Fix round N: <one line>

The previous task is mostly in place. Fix only the items below.

## Already works (do not undo)
- <item that passed verification>

## 1. <symptom, one line>
Ran: `<exact command>`
Expected: <exact expected output>
Got: <exact output>
In: /abs/path/file.py, function `name`
Fix (round 2+): <expected behavior in words>
Exact code (round 3): <the code>
Acceptance: `<command that prints OK for this item>`

## 2. ...

## Final check (run last, paste exact output)
```sh
<one command that prints OK only when every item above passes>
```
```

Even a one-line fix goes in a fix file; Claude does not patch the project itself unless
the user says so.
