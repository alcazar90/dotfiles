# Task file template

Write this in the scratchpad. Pi is a small model: be literal, number everything, give
exact code, use absolute paths, and end with a check that prints OK.

```markdown
# Task: <one line, what and why>

Working dir: /abs/project/dir   (all paths below are absolute)
Do not touch any file not listed here. Do not refactor or rename anything else.

## 1. <file> : <change>
In /abs/path/file.py, in function `name`, replace:
<exact old code>
with:
<exact new code>

## 2. <file> : <change>
...

## Already works (do not change)
- <behavior that must stay identical>

## Check (run this last and paste its exact output)
```sh
cd /abs/project/dir
python -m py_compile file.py
# strict: new output must equal the original's
python file.py | sed 's/\x1b\[[0-9;]*m//g' > /tmp/new.txt
diff /tmp/new.txt /abs/scratchpad/expected.txt && echo OK
```
Report the exact output. It must end with OK.
```

Strict-check rule: if existing behavior must not change, save the original output or file
first (the Snapshot step) and have the check compare against it. A check that only greps
for expected strings lets pi say OK while regressing other things.
