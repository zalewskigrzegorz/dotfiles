# Wait for fix
# source ~/.config/nushell/fzf/completion-bind.nu
# source ~/.config/nushell/fzf/completion-menu.nu
# source ~/.config/nushell/fzf/key-bindings.nu
source ~/.config/nushell/fzf/completion-external.nu


const ctrl_d_binding = {
    name: fzf_dirs
    modifier: control
    keycode: char_d
    mode: [emacs, vi_normal, vi_insert]
    event: { 
        send: executehostcommand
        cmd: "
            let result = (fd --type directory --hidden --exclude .git --exclude node_modules  | fzf --preview 'tree -C {} | head -n 200');
            if not ($result | is-empty) {
                cd $result
            }
        "
    }
}

const ctrl_f_binding = {
    name: fzf_files
    modifier: control
    keycode: char_f
    mode: [emacs, vi_normal, vi_insert]
    event: { 
        send: executehostcommand
        cmd: "
            let result = (fd --type file --hidden --exclude .git --exclude node_modules  | fzf --preview 'bat --color=always --style=full --line-range=:500 {}');
            if not ($result | is-empty) {
                commandline edit --append $result;
                commandline set-cursor --end
            }
        "
    }
}

export-env {
    $env.config.keybindings = ($env.config.keybindings | append [
        $ctrl_d_binding
        $ctrl_f_binding
    ])
}
