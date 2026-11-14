# --- Project Configuration ---
GAME_NAME    := Roibos
TITLE_ID     := 000400000F123400
PRODUCT_CODE := CTR-N-ROIB

# --- Docker & Paths ---
# Derived from the stock Polyphase image; Dockerfile adds makerom, bannertool
# and cxitool, which the stock image does not ship.
DOCKER_BASE  := polyphase-engine:latest
DOCKER_IMAGE := polyphase-engine-3ds
DIST_DIR     := $(CURDIR)/dist
OUT_3DS_DIR  := $(DIST_DIR)/3DS

# --- Banner & Audio Assets (relative to project root) ---
BANNER_IMG   := Assets/banner.png
BANNER_AUDIO := Assets/audio.wav

# --- Local emulator ---
# Use a native azahar binary when present; otherwise fall back to the Flatpak
# install. Override with e.g. `make run AZAHAR=/path/to/azahar`.
AZAHAR           ?= $(shell command -v azahar 2>/dev/null)
AZAHAR_FLATPAK_ID := org.azahar_emu.Azahar

# --- Generated Files (container paths) ---
C_3DSX       := /game/3DS/$(GAME_NAME).3dsx
C_CXI        := /game/3DS/$(GAME_NAME).cxi
C_CIA        := /game/3DS/$(GAME_NAME).cia
C_BNR        := /game/3DS/banner.bnr
C_SILENT_WAV := /game/3DS/silent.wav

# --- Generated Files (host paths for Make dependency tracking) ---
TARGET_3DSX  := $(OUT_3DS_DIR)/$(GAME_NAME).3dsx
TARGET_CXI   := $(OUT_3DS_DIR)/$(GAME_NAME).cxi
TARGET_CIA   := $(OUT_3DS_DIR)/$(GAME_NAME).cia
BANNER_BNR   := $(OUT_3DS_DIR)/banner.bnr
SILENT_WAV   := $(OUT_3DS_DIR)/silent.wav

DOCKER_VOLS  := -v $(DIST_DIR):/game -v $(CURDIR):/project
DOCKER_RUN   := docker run --rm $(DOCKER_VOLS) $(DOCKER_IMAGE)
DOCKER_EXEC  := docker run --rm --entrypoint "" $(DOCKER_VOLS) $(DOCKER_IMAGE)

# bannertool requires an audio track. Fall back to a short silent WAV when the
# project has not supplied one yet so the CIA pipeline is never blocked on it.
ifeq ($(shell test -s "$(BANNER_AUDIO)" && echo yes),yes)
BANNER_AUDIO_ARG := /project/$(BANNER_AUDIO)
BANNER_AUDIO_DEP := $(BANNER_AUDIO)
else
BANNER_AUDIO_ARG := $(C_SILENT_WAV)
BANNER_AUDIO_DEP := $(SILENT_WAV)
endif

.PHONY: all check-project image 3dsx cia run run-cia clean

all: cia

check-project:
	@project=$$(sed -n 's/^Project=//p' $(CURDIR)/Config.ini | head -n1); \
	if [ "$$project" != "$(GAME_NAME)" ]; then \
		echo "Config.ini Project is '$$project' but this build expects '$(GAME_NAME)'." >&2; \
		echo "Restore Project=$(GAME_NAME) in Config.ini and remove any stray .octp files." >&2; \
		exit 1; \
	fi
	@octp_count=$$(find $(CURDIR) -maxdepth 1 -name '*.octp' | wc -l); \
	if [ "$$octp_count" -ne 1 ]; then \
		echo "Expected exactly one .octp project file, found $$octp_count:" >&2; \
		find $(CURDIR) -maxdepth 1 -name '*.octp' -printf '  %f\n' >&2; \
		echo "Keep only $(GAME_NAME).octp and delete the rest." >&2; \
		exit 1; \
	fi
	@octp_file=$$(find $(CURDIR) -maxdepth 1 -name '*.octp' -print -quit); \
	octp_base=$$(basename "$$octp_file" .octp); \
	octp_name=$$(sed -n 's/^name=//p' "$$octp_file" | head -n1); \
	if [ "$$octp_base" != "$(GAME_NAME)" ] || [ "$$octp_name" != "$(GAME_NAME)" ]; then \
		echo "Project file must be $(GAME_NAME).octp with name=$(GAME_NAME)." >&2; \
		echo "Found $$octp_file with name='$$octp_name'." >&2; \
		exit 1; \
	fi

image:
	docker build -f $(CURDIR)/Dockerfile --build-arg BASE_IMAGE=$(DOCKER_BASE) -t $(DOCKER_IMAGE) .

$(SILENT_WAV):
	mkdir -p $(OUT_3DS_DIR)
	$(DOCKER_EXEC) python3 -c 'import wave; w = wave.open("$(C_SILENT_WAV)", "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(32000); w.writeframes(bytes(64000)); w.close()'

3dsx: check-project image
	mkdir -p $(OUT_3DS_DIR)
	$(DOCKER_RUN) build-3ds
	@if [ -f $(DIST_DIR)/$(GAME_NAME).3dsx ]; then \
		mv -f $(DIST_DIR)/$(GAME_NAME).3dsx $(TARGET_3DSX); \
	fi
	@if [ ! -f $(TARGET_3DSX) ]; then \
		echo "build-3ds did not produce $(TARGET_3DSX)." >&2; \
		found=$$(find $(DIST_DIR) -maxdepth 1 -name '*.3dsx' -printf '%f\n'); \
		if [ -n "$$found" ]; then \
			echo "Found these .3dsx files instead:" >&2; \
			echo "$$found" >&2; \
			echo "Check that Roibos.octp has name=Roibos and Config.ini has Project=Roibos." >&2; \
		fi; \
		exit 1; \
	fi

$(BANNER_BNR): $(BANNER_IMG) $(BANNER_AUDIO_DEP)
	mkdir -p $(OUT_3DS_DIR)
	$(DOCKER_EXEC) bannertool makebanner -i /project/$(BANNER_IMG) -a $(BANNER_AUDIO_ARG) -o $(C_BNR)

$(TARGET_CXI): 3dsx $(BANNER_BNR)
	$(DOCKER_EXEC) cxitool -t $(TITLE_ID) -b $(C_BNR) -c $(PRODUCT_CODE) $(C_3DSX) $(C_CXI)

$(TARGET_CIA): $(TARGET_CXI)
	$(DOCKER_EXEC) makerom -f cia -o $(C_CIA) -target t -i $(C_CXI):0:0 -ignoresign
	@echo "Built CIA successfully: $(TARGET_CIA)"

cia: $(TARGET_CIA)

# Build the CIA, install it into Azahar, and open Azahar.
run: cia
	@$(MAKE) --no-print-directory run-cia

# Install the existing CIA into Azahar and open Azahar without rebuilding.
# Launch "Roibos" from Azahar's game list afterwards.
run-cia:
	@test -f "$(TARGET_CIA)" || { \
		echo "Missing $(TARGET_CIA). Run 'make cia' first." >&2; \
		exit 1; \
	}
	@set -e; \
	if [ -n "$(AZAHAR)" ]; then \
		run_azahar() { "$(AZAHAR)" "$$@"; }; \
	elif command -v flatpak >/dev/null 2>&1 && flatpak info $(AZAHAR_FLATPAK_ID) >/dev/null 2>&1; then \
		run_azahar() { flatpak run $(AZAHAR_FLATPAK_ID) "$$@"; }; \
	else \
		echo "Azahar not found. Install Azahar or set AZAHAR=/path/to/azahar." >&2; \
		exit 1; \
	fi; \
	echo "Installing $(TARGET_CIA) into Azahar..."; \
	run_azahar -i "$(abspath $(TARGET_CIA))"; \
	echo "Opening Azahar. Launch 'Roibos' from the game list."; \
	run_azahar

clean:
	rm -rf $(DIST_DIR)
