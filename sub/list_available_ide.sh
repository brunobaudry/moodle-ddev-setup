#!/bin/bash
available_ides=()
names=()
if command -v phpstorm >/dev/null 2>&1; then
    available_ides+=("phpstorm")
    names+=("PhpStorm (phpstorm)")
fi
if command -v netbeans >/dev/null 2>&1; then
    available_ides+=("netbeans")
    names+=("NetBeans (netbeans)")
fi
if command -v eclipse >/dev/null 2>&1; then
    available_ides+=("eclipse")
    names+=("Eclipse (eclipse)")
fi
if command -v code >/dev/null 2>&1; then
    available_ides+=("code")
    names+=("VS Code (code)")
fi
if command -v subl >/dev/null 2>&1; then
    available_ides+=("subl")
    names+=("Sublime Text (subl)")
fi
if command -v atom >/dev/null 2>&1; then
    available_ides+=("atom")
    names+=("Atom (atom)")
fi
if command -v geany >/dev/null 2>&1; then
    available_ides+=("geany")
    names+=("Geany (geany)")
fi
if command -v bluefish >/dev/null 2>&1; then
    available_ides+=("bluefish")
    names+=("Bluefish (bluefish)")
fi
if command -v vim >/dev/null 2>&1; then
    available_ides+=("vim")
    names+=("Vim (vim)")
fi
if command -v nano >/dev/null 2>&1; then
    available_ides+=("nano")
    names+=("Nano (nano)")
fi
echo 'IDEs found:'
for i in "${!names[@]}"; do
    echo "$((i+1)). ${names[$i]}"
done
# Export arrays for parent script
export available_ides names