# Auditoria Debian Tunado 3.0

**Data:** 2026-03-07 13:12:41  
**Total verificações:** 59  
**✅ PASS:** 14 | **❌ FAIL:** 38 | **⚠️ WARN:** 7  
**Conformidade:** 23.7%

---

## Resumo

❌ **REQUER ATENÇÃO**

---

## ❌ CRÍTICO (38 itens)

- RAM: 8GB disponível → 8GB DDR4
- Kernel: i915.enable_guc=3 → enable_guc=3
- Kernel: intel_pstate=active → intel_pstate=active
- Kernel: blacklist NVIDIA no cmdline → blacklist nouveau,nvidia...
- Arquivo: blacklist-nvidia.conf existe → blacklist-nvidia.conf
- Blacklist: nouveau listado → blacklist nouveau
- Blacklist: nvidia listado → blacklist nvidia
- Módulo: nouveau NÃO carregado → nouveau não carregado
- Pacote: intel-media-va-driver-non-free → driver iHD
- VA-API: Driver iHD ativo → Intel iHD driver
- VA-API: H.264 encode disponível → VAEntrypointEncSlice
- Subvolume: @home existe → subvol=@home
- Subvolume: @docker existe → subvol=@docker
- Subvolume: @postgres existe → subvol=@postgres
- Subvolume: @var existe → subvol=@var
- Subvolume: @snapshots existe → subvol=@snapshots
- Mount: compress=zstd → compress=zstd
- Mount: noatime → noatime
- Mount: discard=async → discard=async
- Pacote: zram-tools instalado → zram-tools
- Config: /etc/default/zramswap existe → /etc/default/zramswap
- ZRAM: ALGO=zstd → ALGO=zstd
- ZRAM: SIZE=4096 → SIZE=4096
- Device: /dev/zram0 ativo → /dev/zram0
- Diretório: /swap existe → /swap
- Swapfile: /swap/swapfile existe → /swap/swapfile
- Swap: ativado → swap ativo
- Fstab: swapfile configurado → fstab entry
- Arquivo: 99-performance.conf existe → 99-performance.conf
- Sysctl: vm.swappiness=150 → swappiness=150 (atual: 0)
- Sysctl: vm.overcommit_memory=2 → overcommit_memory=2 (atual: 0)
- Pacote: msr-tools instalado → msr-tools
- Script: tdp-unlock.sh existe → tdp-unlock.sh
- Script: PL1=20W configurado → PL1=20W PL2=25W
- Script: Turbo 2.7GHz (0x1B) → Turbo 2.7GHz
- Serviço: tdp-unlock.service habilitado → tdp-unlock enabled
- Pacote: thermald instalado → thermald
- Grupo: render → grupo render

---

## ⚠️ RECOMENDADO (7 itens)

- Hardware: Lenovo 310-15ISK detectado → Lenovo 310-15ISK
- Kernel: mitigations=off → mitigations=off
- Sysctl: tcp_congestion_control=bbr → tcp_cc=bbr (atual: none)
- Docker: instalado → docker
- Docker: overlay2 → overlay2
- i3wm: instalado → i3-wm
- LightDM: instalado → lightdm

---

## ✅ CORRETO (14 itens)

- CPU: Intel i5-6200U (Skylake) → i5-6200U @ 2.30GHz
- SSD: 480GB detectado → 480GB SSD
- OS: Debian 12 (bookworm) → Debian GNU/Linux 12
- Firmware: DMC presente → skl_dmc_*.bin
- Firmware: GuC presente → skl_guc_*.bin
- Firmware: HuC presente → skl_huc_*.bin
- Filesystem: Root é BTRFS → btrfs
- Subvolume: @ existe → subvol=@
- Serviço: zramswap ativo → zramswap active
- Serviço: thermald ativo → thermald active
- Serviço: fstrim.timer habilitado → fstrim.timer enabled
- Docker: serviço ativo → docker active
- Usuário: highlander existe → highlander
- Grupo: video → grupo video

---

## Comandos rápidos para correção

```bash
# Instalar pacotes faltantes
apt update
apt install -y intel-media-va-driver-non-free vainfo thermald zram-tools linux-cpupower msr-tools

# Corrigir GRUB
nano /etc/default/grub
# Adicionar: i915.enable_guc=3 intel_pstate=active mitigations=off modprobe.blacklist=nouveau,nvidia,nvidia_drm,nvidia_modeset
update-grub

# Criar blacklist NVIDIA
cat > /etc/modprobe.d/blacklist-nvidia.conf << 'EOF'
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
options nouveau modeset=0
