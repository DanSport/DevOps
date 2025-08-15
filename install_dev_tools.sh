#!/usr/bin/env bash
set -euo pipefail

# ----------------- helpers -----------------
have() { command -v "$1" >/dev/null 2>&1; }
log()  { echo -e "\033[1;32m==>\033[0m $*"; }
warn() { echo -e "\033[1;33m[warn]\033[0m $*"; }
err()  { echo -e "\033[1;31m[err]\033[0m  $*"; }

os_family() {
  case "$(uname -s)" in
    Linux)  echo linux ;;
    Darwin) echo mac ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo unknown ;;
  esac
}

ver_ge() { # dpkg-style compare if available, else python
  if have dpkg; then
    dpkg --compare-versions "$1" ge "$2"
  else
    python_cmd=$(command -v python3 || command -v python || true)
    "$python_cmd" - "$1" "$2" <<'PY' >/dev/null 2>&1 || exit 0
import sys, pkgutil
a,b=sys.argv[1],sys.argv[2]
from distutils.version import LooseVersion as V
sys.exit(0 if V(a) >= V(b) else 1)
PY
  fi
}

# ----------------- Docker + Compose check -----------------
check_docker() {
  if have docker; then
    log "Docker: $(docker --version)"
    if docker compose version >/dev/null 2>&1; then
      log "Docker Compose: $(docker compose version | head -n1)"
    else
      warn "Docker Compose не знайдено."
      return 1
    fi
    return 0
  fi
  return 1
}

# ----------------- installers -----------------
install_linux() {
  # Ubuntu/Debian
  if ! have apt-get; then
    err "Підтримується Ubuntu/Debian (apt). Ваш дистрибутив не має apt."
    exit 1
  fi
  sudo -v
  sudo apt-get update -y

  if ! check_docker; then
    log "Встановлення Docker CE + Compose (apt)…"
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -d -m 0755 /etc/apt/keyrings || true
    if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
      curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
    fi
    codename=$(. /etc/os-release; echo "$VERSION_CODENAME")
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $codename stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER" || true
  fi

  # Python >= 3.9 + pip
  PY_OK=false
  if have python3; then
    v=$(python3 -c 'import sys;print(".".join(map(str,sys.version_info[:3])))')
    if ver_ge "$v" "3.9"; then PY_OK=true; log "Python3 OK ($v)"; fi
  fi
  if [[ "$PY_OK" != true ]]; then
    log "Встановлення Python 3.11 + pip…"
    sudo apt-get install -y python3 python3-venv python3-pip || {
      # для старих Ubuntu:
      sudo apt-get install -y software-properties-common
      sudo add-apt-repository -y ppa:deadsnakes/ppa
      sudo apt-get update -y
      sudo apt-get install -y python3.11 python3.11-venv python3-pip
      sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2
    }
  fi

  # Django (user install)
  if python3 -m django --version >/dev/null 2>&1; then
    log "Django: $(python3 -m django --version)"
  else
    log "Встановлення Django (pip --user)…"
    python3 -m pip install --user --upgrade pip
    python3 -m pip install --user Django
    log "Django: $(python3 -m django --version)"
  fi
}

install_mac() {
  # Homebrew
  if ! have brew; then
    log "Встановлення Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bashrc
    eval "$(/opt/homebrew/bin/brew shellenv)" || true
  fi

  if ! check_docker; then
    log "Встановлення Docker Desktop…"
    brew install --cask docker
    open -a Docker || true
    warn "Запусти Docker Desktop і дочекайся, доки він стартує."
  fi

  if have python3; then
    v=$(python3 -c 'import sys;print(".".join(map(str,sys.version_info[:3])))')
    if ! ver_ge "$v" "3.9"; then brew install python@3.11; fi
  else
    brew install python@3.11
  fi

  if python3 -m django --version >/dev/null 2>&1; then
    log "Django: $(python3 -m django --version)"
  else
    python3 -m pip install --user --upgrade pip
    python3 -m pip install --user Django
    log "Django: $(python3 -m django --version)"
  fi
}

install_windows() {
  # Працює з Git Bash/MinGW: викликаємо PowerShell + winget
  PS='powershell.exe -NoProfile -ExecutionPolicy Bypass -Command'

  if ! check_docker; then
    log "Встановлення Docker Desktop через winget…"
    $PS 'winget install -e --id Docker.DockerDesktop -h || exit $LastExitCode'
    warn "Після інсталяції Docker Desktop відкрий його один раз. У Settings → Resources → WSL integration ввімкни інтеграцію (за потреби)."
  fi

  # Python (через winget)
  PY_OK=false
  if command -v py >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
    v=$((command -v python3 >/dev/null 2>&1 && python3 -c 'import sys;print(".".join(map(str,sys.version_info[:3])))') || py -3 -c 'import sys;print(".".join(map(str,sys.version_info[:3])))')
    if ver_ge "$v" "3.9"; then PY_OK=true; log "Python OK ($v)"; fi
  fi
  if [[ "$PY_OK" != true ]]; then
    log "Встановлення Python 3 через winget…"
    $PS 'winget install -e --id Python.Python.3.11 -h || exit $LastExitCode'
  fi

  # Django
  if py -3 -m django --version >/dev/null 2>&1 || python3 -m django --version >/dev/null 2>&1; then
    dj=$((py -3 -m django --version 2>/dev/null) || (python3 -m django --version 2>/dev/null) || echo '')
    log "Django: $dj"
  else
    log "Встановлення Django (pip для поточного користувача)…"
    if command -v py >/dev/null 2>&1; then
      py -3 -m pip install --upgrade pip
      py -3 -m pip install --user Django
      py -3 -m django --version
    else
      python3 -m pip install --upgrade pip
      python3 -m pip install --user Django
      python3 -m django --version
    fi
  fi
}

# ----------------- main -----------------
case "$(os_family)" in
  linux)   install_linux ;;
  mac)     install_mac ;;
  windows) install_windows ;;
  *)
    err "Непідтримувана ОС. Підтримуються: Ubuntu/Debian, macOS, Windows (winget/Docker Desktop)."
    exit 1
    ;;
esac

log "ГОТОВО ✅  Docker, Docker Compose, Python (>=3.9) і Django встановлені/перевірені."
