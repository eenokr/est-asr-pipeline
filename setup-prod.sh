#!/bin/bash
set -e
echo "=== Est-ASR Pipeline setup ==="

OS=$(uname -s)
ARCH=$(uname -m)
echo "Süsteem: $OS / $ARCH"

# 1. Java 21
echo "Installiin Java 21..."
if [ "$OS" = "Darwin" ]; then
  brew install openjdk@21
  export PATH="$(brew --prefix)/opt/openjdk@21/bin:$PATH"
  sudo ln -sfn $(brew --prefix)/opt/openjdk@21/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-21.jdk
elif [ -f /etc/debian_version ]; then
  apt-get update -qq
  apt-get install -y openjdk-21-jre-headless curl ca-certificates
  update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java 2>/dev/null || true
fi
java -version

# 2. Docker
if ! command -v docker &>/dev/null; then
  echo "Installiin Docker..."
  curl -fsSL https://get.docker.com | bash
  systemctl enable docker
  systemctl start docker
  # Lisa kasutaja docker gruppi
  SUDO_USER=${SUDO_USER:-$USER}
  if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    usermod -aG docker "$SUDO_USER"
    echo "NB: Logi välja ja sisse et Docker ilma sudo töötaks"
  fi
else
  echo "Docker on juba installitud"
fi
docker --version

# 3. Nextflow
echo "Installiin Nextflow..."
curl -s https://get.nextflow.io | bash
mv nextflow /usr/local/bin/
nextflow -version

# 4. Docker image
echo "Tõmban Docker image (~8GB, võtab aega)..."
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  echo "ARM tuvastatud - kasutan emulatsioonirežiimi"
  docker pull --platform linux/amd64 eenokr/est-asr:latest
else
  docker pull eenokr/est-asr:latest
fi

# 5. Pipeline failid
echo "Kopeerin pipeline failid..."
mkdir -p /opt/est-asr-pipeline
docker create --name tmp_setup --platform linux/amd64 eenokr/est-asr:latest
docker cp tmp_setup:/opt/est-asr-pipeline/transcribe.nf /opt/est-asr-pipeline/
docker cp tmp_setup:/opt/est-asr-pipeline/nextflow.config /opt/est-asr-pipeline/
docker rm tmp_setup

# 6. Transkribeerimise skript
PLATFORM_OPT=""
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  PLATFORM_OPT="--platform linux/amd64"
fi

cat > /usr/local/bin/transkribeeri << SCRIPT
#!/bin/bash
set -e
if [ -z "\$1" ]; then
  echo "Kasutus: transkribeeri <helifail.mp3>"
  exit 1
fi
FAIL="\$1"
NIMI=\$(basename "\$FAIL" | sed 's/\.[^.]*\$//')
TULEMUS="\${2:-/opt/tulemused/\$NIMI}"
mkdir -p "\$TULEMUS"
echo "Transkribeerin: \$FAIL"
cd /opt/est-asr-pipeline
nextflow run transcribe.nf -profile docker $PLATFORM_OPT \
  --in "\$FAIL" \
  --out_dir "\$TULEMUS" \
  --nthreads 4 \
  --do_speaker_id false
echo "Valmis! Tulemus: \$TULEMUS"
ls "\$TULEMUS/"
SCRIPT
chmod +x /usr/local/bin/transkribeeri

echo ""
echo "=== Setup valmis! ==="
echo "Kasutus: transkribeeri /tee/fail.mp3"
