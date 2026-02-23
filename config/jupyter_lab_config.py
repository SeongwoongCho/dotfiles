"""JupyterLab configuration for dotfiles.

Applied via symlink: ~/.jupyter/jupyter_lab_config.py -> dotfiles/config/jupyter_lab_config.py
"""

c = get_config()  # noqa

# Disable token and password authentication for local development
c.ServerApp.token = ""
c.ServerApp.password = ""
c.ServerApp.password_required = False

# Allow access from any origin (useful for remote dev containers)
c.ServerApp.allow_origin = "*"

# Listen on all interfaces (needed for Docker/remote access)
c.ServerApp.ip = "0.0.0.0"

# Don't auto-open browser (headless/remote environments)
c.ServerApp.open_browser = False
