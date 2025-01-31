return {
    'dense-analysis/ale',
    config = function()
        -- Configuration goes here.
        local g = vim.g

        -- Flake8 options 설정
        g.ale_python_flake8_options = "--ignore=E501,E701,E702"

        g.ale_python_pylint_executable = ''
        g.ale_fix_on_save = 1

        -- fixers 설정
        g.ale_fixers = {
            python = {'remove_trailing_lines', 'trim_whitespace', 'isort'},
        }
    end
}


