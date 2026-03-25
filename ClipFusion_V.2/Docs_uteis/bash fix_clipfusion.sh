"""
ClipFusion Viral Pro — Interface principal (Tkinter)
7 abas: Projeto | Transcrição | IA Externa | Cortes | Render | Histórico | Agenda
Lazy loading: viral_engine só importa quando usa (economiza ~300MB RAM idle)
gc.collect() explícito após render (crucial para 8GB RAM)
"""
import tkinter as tk
from tkinter import ttk, messagebox, filedialog, scrolledtext
import threading, os, gc, json, subprocess
from pathlib import Path
from datetime import datetime

import db
from utils.hardware import HardwareDetector, check_system
from core.transcriber import WhisperTranscriber, fmt_time
from core.prompt_builder import build_analysis_prompt, parse_ai_response
from core.cut_engine import render_all, _detect_vaapi
from anti_copy_modules.core import LEVEL_LABELS

BG   = "#0d0d1a"; BG2  = "#151528"; BG3  = "#1e1e3a"
ACC  = "#7c3aed"; GRN  = "#22c55e"; RED  = "#ef4444"
YEL  = "#f59e0b"; WHT  = "#f1f5f9"; GRY  = "#64748b"
FNT  = ("Segoe UI", 10); FNTB = ("Segoe UI", 10, "bold")
FNTL = ("Segoe UI", 13, "bold"); MONO = ("Consolas", 9)

ACE_LEVELS = [
    ("🟢 NENHUM",  "none"),
    ("🟡 BÁSICO",  "basic"),
    ("🟠 ANTI-IA", "anti_ai"),
    ("🔴 MÁXIMO",  "maximum"),
]


class ClipFusionApp:

    def __init__(self):
        self.root = tk.Tk()
        self.root.title("✂ ClipFusion Viral Pro")
        self.root.geometry("1120x800")
        self.root.configure(bg=BG)
        self.root.resizable(True, True)

        self.project_id = None
        self.video_path = None
        self.segments   = []
        self.duration   = 0.0
        self.cut_vars   = {}
        self.output_dir = None

        self.project_root = None
        self.source_dir   = None
        self.work_dir     = None
        self.state_dir    = None

        self.transcribing = False
        self.rendering = False

        self.btn_select_video = None
        self.btn_transcribe = None
        self.btn_render = None

        # Detecta hardware uma vez no boot da GUI
        self.hw = HardwareDetector()

        self._build_ui()

    def run(self):
        self.root.mainloop()

    def _build_ui(self):
        hdr = tk.Frame(self.root, bg=ACC, height=54)
        hdr.pack(fill="x")
        tk.Label(
            hdr,
            text="✂  ClipFusion Viral Pro",
            font=("Segoe UI", 16, "bold"),
            bg=ACC,
            fg=WHT,
        ).pack(side="left", padx=20, pady=12)
        tk.Label(
            hdr,
            text="vídeo longo → cortes virais prontos pra postar",
            font=FNT,
            bg=ACC,
            fg="#c4b5fd",
        ).pack(side="left")
        self.lbl_hw = tk.Label(
            hdr,
            text=self.hw.get_status_string(),
            font=("Segoe UI", 8),
            bg=ACC,
            fg="#c4b5fd",
        )
        self.lbl_hw.pack(side="right", padx=16)

        s = ttk.Style()
        s.theme_use("clam")
        s.configure("TNotebook", background=BG2, borderwidth=0)
        s.configure("TNotebook.Tab", background=BG3, foreground=GRY, padding=[14, 7], font=FNT)
        s.map("TNotebook.Tab", background=[("selected", ACC)], foreground=[("selected", WHT)])

        self.nb = ttk.Notebook(self.root)
        self.nb.pack(fill="both", expand=True)

        self._tab_projeto()
        self._tab_transcricao()
        self._tab_ia()
        self._tab_cortes()
        self._tab_render()
        self._tab_historico()
        self._tab_agenda()

    # ── Tab 1: Projeto ────────────────────────────────────────────────────────

    def _tab_projeto(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="📁  Projeto")

        self._lbl(f, "Novo projeto", font=FNTL).pack(anchor="w", padx=30, pady=(28, 4))
        self._lbl(f, "Selecione o vídeo longo e configure as opções.", color=GRY).pack(anchor="w", padx=30)
        self._sep(f)

        r1 = tk.Frame(f, bg=BG2)
        r1.pack(fill="x", padx=30, pady=6)
        self._lbl(r1, "Nome:").pack(side="left")
        self.v_name = tk.StringVar(value=f"Projeto {datetime.now().strftime('%d/%m %H:%M')}")
        tk.Entry(
            r1,
            textvariable=self.v_name,
            width=44,
            bg=BG3,
            fg=WHT,
            insertbackground=WHT,
            relief="flat",
            font=FNT,
        ).pack(side="left", padx=10)

        self._lbl(f, "Contexto (opcional — ajuda a IA entender o tema):").pack(anchor="w", padx=30, pady=(12, 4))
        self.ctx_box = tk.Text(
            f,
            height=3,
            bg=BG3,
            fg=WHT,
            insertbackground=WHT,
            relief="flat",
            font=FNT,
            wrap="word",
        )
        self.ctx_box.pack(fill="x", padx=30)
        self.ctx_box.insert("1.0", "Ex: Podcast sobre vendas — episódio sobre prospecção de clientes.")
        self._sep(f)

        vr = tk.Frame(f, bg=BG2)
        vr.pack(fill="x", padx=30, pady=6)
        self.btn_select_video = self._btn(vr, "📂 Selecionar vídeo", self._select_video, ACC)
        self.btn_select_video.pack(side="left")
        self.lbl_video = self._lbl(vr, "Nenhum vídeo selecionado", color=GRY)
        self.lbl_video.pack(side="left", padx=14)

        op = tk.Frame(f, bg=BG2)
        op.pack(fill="x", padx=30, pady=10)
        self.v_vaapi = tk.BooleanVar(value=True)
        self._chk(op, "Usar VA-API (Intel HD 520) — recomendado", self.v_vaapi).pack(anchor="w")

        acef = tk.Frame(f, bg=BG2)
        acef.pack(fill="x", padx=30, pady=4)
        self._lbl(acef, "Anti-Copyright:").pack(side="left")
        self.v_ace = tk.StringVar(value="basic")
        for lbl, val in ACE_LEVELS:
            tk.Radiobutton(
                acef,
                text=lbl,
                variable=self.v_ace,
                value=val,
                bg=BG2,
                fg=WHT,
                selectcolor=ACC,
                activebackground=BG2,
                font=FNT,
            ).pack(side="left", padx=8)

        wf = tk.Frame(f, bg=BG2)
        wf.pack(fill="x", padx=30, pady=4)
        self._lbl(wf, "Whisper:").pack(side="left")
        self.v_whisper = tk.StringVar(value="tiny")
        for m in ["tiny", "base", "small"]:
            tk.Radiobutton(
                wf,
                text=m,
                variable=self.v_whisper,
                value=m,
                bg=BG2,
                fg=WHT,
                selectcolor=ACC,
                activebackground=BG2,
                font=FNT,
            ).pack(side="left", padx=8)

        lf = tk.Frame(f, bg=BG2)
        lf.pack(fill="x", padx=30, pady=4)
        self._lbl(lf, "Idioma:").pack(side="left")
        self.v_lang = tk.StringVar(value="en")
        for lbl, val in [("Auto", "auto"), ("Português", "pt"), ("English", "en")]:
            tk.Radiobutton(
                lf,
                text=lbl,
                variable=self.v_lang,
                value=val,
                bg=BG2,
                fg=WHT,
                selectcolor=ACC,
                activebackground=BG2,
                font=FNT,
            ).pack(side="left", padx=8)

        self._sep(f)
        self.btn_transcribe = self._btn(f, "▶  Iniciar Transcrição", self._start_transcription, GRN, wide=True)
        self.btn_transcribe.pack(padx=30, pady=8)
        self.lbl_status = self._lbl(f, "", color=GRY)
        self.lbl_status.pack(padx=30, pady=4)

    # ── Tab 2: Transcrição ────────────────────────────────────────────────────

    def _tab_transcricao(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="📝  Transcrição")

        self._lbl(f, "Transcrição com timestamps", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        self._lbl(f, "Gerada pelo Whisper. Revise se necessário.", color=GRY).pack(anchor="w", padx=30)
        self.box_transcript = scrolledtext.ScrolledText(
            f,
            bg=BG3,
            fg=WHT,
            font=MONO,
            relief="flat",
            insertbackground=WHT,
        )
        self.box_transcript.pack(fill="both", expand=True, padx=30, pady=12)
        self._btn(f, "▶  Gerar Prompt para IA  →", self._goto_ia, ACC, wide=True).pack(padx=30, pady=(0, 20))

    # ── Tab 3: IA Externa ─────────────────────────────────────────────────────

    def _tab_ia(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="🤖  IA Externa")

        top = tk.Frame(f, bg=BG2)
        top.pack(fill="x", padx=30, pady=(20, 4))
        self._lbl(top, "Prompt para copiar", font=FNTL).pack(side="left")
        self._btn(top, "📋 Copiar", self._copy_prompt, ACC).pack(side="right")
        self._lbl(
            f,
            "Cole no Claude.ai, ChatGPT ou qualquer IA. Traga o JSON de resposta abaixo.",
            color=GRY,
        ).pack(anchor="w", padx=30)

        self.box_prompt = scrolledtext.ScrolledText(
            f,
            height=11,
            bg=BG3,
            fg="#a5b4fc",
            font=MONO,
            relief="flat",
            insertbackground=WHT,
        )
        self.box_prompt.pack(fill="x", padx=30, pady=(4, 14))

        self._lbl(f, "Resposta da IA (cole o JSON aqui):", font=FNTB).pack(anchor="w", padx=30)
        self.box_resp = scrolledtext.ScrolledText(
            f,
            height=13,
            bg=BG3,
            fg=GRN,
            font=MONO,
            relief="flat",
            insertbackground=WHT,
        )
        self.box_resp.pack(fill="both", expand=True, padx=30, pady=4)

        self._btn(
            f,
            "✅  Processar resposta  →  Ver Cortes",
            self._process_resp,
            GRN,
            wide=True,
        ).pack(padx=30, pady=(4, 20))

    # ── Tab 4: Cortes ─────────────────────────────────────────────────────────

    def _tab_cortes(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="✂  Cortes")

        top = tk.Frame(f, bg=BG2)
        top.pack(fill="x", padx=30, pady=(20, 4))
        self._lbl(top, "Cortes sugeridos pela IA", font=FNTL).pack(side="left")
        self._btn(top, "✅ Todos", self._approve_all, GRN).pack(side="right", padx=4)
        self._btn(top, "❌ Nenhum", self._reject_all, RED).pack(side="right")
        self._lbl(f, "Marque os cortes que deseja renderizar.", color=GRY).pack(anchor="w", padx=30)

        outer = tk.Frame(f, bg=BG2)
        outer.pack(fill="both", expand=True, padx=30, pady=8)
        cv = tk.Canvas(outer, bg=BG2, highlightthickness=0)
        sb = ttk.Scrollbar(outer, orient="vertical", command=cv.yview)
        self.cuts_frame = tk.Frame(cv, bg=BG2)
        self.cuts_frame.bind("<Configure>", lambda e: cv.configure(scrollregion=cv.bbox("all")))
        cv.create_window((0, 0), window=self.cuts_frame, anchor="nw")
        cv.configure(yscrollcommand=sb.set)
        cv.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")
        cv.bind_all("<MouseWheel>", lambda e: cv.yview_scroll(-1 * (e.delta // 120), "units"))

        self.btn_render = self._btn(f, "🎬  Renderizar cortes aprovados", self._start_render, ACC, wide=True)
        self.btn_render.pack(padx=30, pady=(4, 20))

    # ── Tab 5: Render ─────────────────────────────────────────────────────────

    def _tab_render(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="🎬  Render")

        self._lbl(f, "Progresso do render", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        self.box_log = scrolledtext.ScrolledText(
            f,
            bg=BG3,
            fg=GRN,
            font=MONO,
            relief="flat",
            insertbackground=WHT,
        )
        self.box_log.pack(fill="both", expand=True, padx=30, pady=10)
        self._btn(f, "📂  Abrir pasta de saída", self._open_output, GRY, wide=True).pack(padx=30, pady=(0, 20))

    # ── Tab 6: Histórico ──────────────────────────────────────────────────────

    def _tab_historico(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="📋  Histórico")

        self._lbl(f, "Projetos anteriores", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        cols = ("ID", "Nome", "Status", "Criado em")

        st = ttk.Style()
        st.configure("Treeview", background=BG3, foreground=WHT, fieldbackground=BG3, rowheight=28)
        st.configure("Treeview.Heading", background=ACC, foreground=WHT)

        self.tree = ttk.Treeview(f, columns=cols, show="headings", selectmode="browse")
        for c in cols:
            self.tree.heading(c, text=c)
            self.tree.column(c, width=50 if c == "ID" else 200)
        self.tree.pack(fill="both", expand=True, padx=30, pady=10)

        self._btn(f, "🔄  Carregar projeto selecionado", self._load_project, ACC, wide=True).pack(
            padx=30, pady=(0, 20)
        )
        self._refresh_tree()

    # ── Tab 7: Agenda ─────────────────────────────────────────────────────────

    def _tab_agenda(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="📅  Agenda")

        self._lbl(f, "Agenda de Upload", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        self._lbl(f, "Gera horários ideais com jitter anti-padrão para evitar detecção.", color=GRY).pack(
            anchor="w", padx=30
        )
        self._sep(f)

        cfg = tk.Frame(f, bg=BG2)
        cfg.pack(fill="x", padx=30, pady=8)
        self._lbl(cfg, "Plataforma:").pack(side="left")
        self.v_platform = tk.StringVar(value="tiktok")
        for p in ["tiktok", "instagram", "youtube", "kwai"]:
            tk.Radiobutton(
                cfg,
                text=p,
                variable=self.v_platform,
                value=p,
                bg=BG2,
                fg=WHT,
                selectcolor=ACC,
                activebackground=BG2,
                font=FNT,
            ).pack(side="left", padx=8)

        cfg2 = tk.Frame(f, bg=BG2)
        cfg2.pack(fill="x", padx=30, pady=4)
        self._lbl(cfg2, "Quantidade:").pack(side="left")
        self.v_count = tk.StringVar(value="10")
        tk.Entry(
            cfg2,
            textvariable=self.v_count,
            width=6,
            bg=BG3,
            fg=WHT,
            insertbackground=WHT,
            relief="flat",
            font=FNT,
        ).pack(side="left", padx=10)

        self._btn(f, "📅  Gerar Agenda", self._generate_schedule, ACC, wide=True).pack(padx=30, pady=10)
        self.box_agenda = scrolledtext.ScrolledText(
            f,
            bg=BG3,
            fg=GRN,
            font=MONO,
            relief="flat",
            insertbackground=WHT,
        )
        self.box_agenda.pack(fill="both", expand=True, padx=30, pady=10)

    # ── Helpers de projeto ────────────────────────────────────────────────────

    def _infer_project_dirs(self, video_path: str):
        p = Path(video_path).resolve()
        if p.parent.name == "source":
            root = p.parent.parent
        else:
            root = p.parent

        self.project_root = str(root)
        self.source_dir   = str(root / "source")
        self.work_dir     = str(root / "work")
        self.output_dir   = str(root / "output")
        self.state_dir    = str(root / "state")

    def _ensure_project_dirs(self):
        for d in [self.source_dir, self.work_dir, self.output_dir, self.state_dir]:
            if d:
                os.makedirs(d, exist_ok=True)

    def _state_file(self):
        return os.path.join(self.state_dir, "project_state.json")

    def _save_state(self, extra=None):
        if not self.state_dir:
            return

        data = {
            "project_id": self.project_id,
            "project_name": self.v_name.get().strip(),
            "video_path": self.video_path,
            "project_root": self.project_root,
            "source_dir": self.source_dir,
            "work_dir": self.work_dir,
            "output_dir": self.output_dir,
            "state_dir": self.state_dir,
            "duration": self.duration,
            "segments_count": len(self.segments),
            "whisper_model": self.v_whisper.get(),
            "language": self.v_lang.get(),
            "anti_copy": self.v_ace.get(),
            "use_vaapi": self.v_vaapi.get(),
            "updated_at": datetime.now().isoformat(),
        }

        if extra:
            data.update(extra)

        with open(self._state_file(), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def _write_work_file(self, filename: str, content: str):
        if not self.work_dir:
            return
        with open(os.path.join(self.work_dir, filename), "w", encoding="utf-8") as f:
            f.write(content)

    def _write_work_json(self, filename: str, data):
        if not self.work_dir:
            return
        with open(os.path.join(self.work_dir, filename), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    # ── Helpers de UI ─────────────────────────────────────────────────────────

    def _set_transcribing(self, is_running: bool):
        self.transcribing = is_running
        if self.btn_transcribe:
            self.btn_transcribe.config(
                state=("disabled" if is_running else "normal"),
                text=("⏳ Transcrevendo..." if is_running else "🔁 Retranscrever"),
            )
        if self.btn_select_video:
            self.btn_select_video.config(state=("disabled" if is_running else "normal"))

    def _set_rendering(self, is_running: bool):
        self.rendering = is_running
        if self.btn_render:
            self.btn_render.config(
                state=("disabled" if is_running else "normal"),
                text=("⏳ Renderizando..." if is_running else "🎬  Renderizar cortes aprovados"),
            )

    # ── Ações ─────────────────────────────────────────────────────────────────

    def _select_video(self):
        p = filedialog.askopenfilename(
            title="Selecionar vídeo",
            filetypes=[("Vídeos", "*.mp4 *.mkv *.mov *.avi *.webm"), ("Todos", "*.*")],
        )

        if not p:
            return

        self.video_path = p
        self._infer_project_dirs(p)
        self._ensure_project_dirs()

        self.lbl_video.config(
            text=f"✅ {os.path.basename(p)} | raiz: {os.path.basename(self.project_root)}",
            fg=GRN,
        )
        self._status(f"Vídeo selecionado. Projeto: {self.project_root}", GRN)

    def _start_transcription(self):
        if self.transcribing:
            return

        if not self.video_path:
            messagebox.showwarning("Atenção", "Selecione um vídeo primeiro.")
            return

        self._set_transcribing(True)

        name = self.v_name.get().strip() or "Sem nome"
        pid = db.create_project(name, self.video_path)
        self.project_id = pid

        if not self.project_root:
            self._infer_project_dirs(self.video_path)
        self._ensure_project_dirs()
        self._save_state({"stage": "transcription_started", "status": "running"})

        self._status(f"Projeto #{pid} criado. Transcrevendo...", YEL)

        def run():
            def log(m):
                self.root.after(0, lambda msg=m: self._status(msg, YEL))

            try:
                lang = self.v_lang.get()
                lang = None if lang == "auto" else lang

                transcriber = WhisperTranscriber(
                    model=self.v_whisper.get(),
                    language=lang,
                )
                res = transcriber.transcribe(self.video_path, progress_callback=log)

                self.segments = res["segments"]
                self.duration = self.segments[-1]["end"] if self.segments else 0

                db.save_transcription(pid, res["full_text"], self.segments)
                db.update_project_status(pid, "transcrito")

                self._write_work_file("transcription.txt", res["full_text"])
                self._write_work_json("transcription_segments.json", self.segments)

                ctx = self.ctx_box.get("1.0", "end").strip()
                ctx = "" if ctx.startswith("Ex:") else ctx
                prompt = build_analysis_prompt(self.segments, self.duration, ctx)

                self._write_work_file("analysis_prompt.txt", prompt)
                self._save_state({
                    "stage": "transcription_done",
                    "status": "ok",
                    "prompt_file": os.path.join(self.work_dir, "analysis_prompt.txt"),
                })

                def update():
                    self.box_transcript.delete("1.0", "end")
                    for s in self.segments:
                        self.box_transcript.insert("end", f"[{fmt_time(s['start'])}] {s['text']}\n")
                    self.box_prompt.delete("1.0", "end")
                    self.box_prompt.insert("1.0", prompt)
                    self._status(f"✅ {len(self.segments)} segmentos. Vá para 🤖 IA Externa.", GRN)
                    self.nb.select(1)
                    self._set_transcribing(False)

                self.root.after(0, update)

            except Exception as e:
                err_msg = str(e)
                self._save_state({"stage": "transcription_error", "status": "error", "error": err_msg})

                def fail():
                    messagebox.showerror("Erro", err_msg)
                    self._status(f"Erro: {err_msg}", RED)
                    self._set_transcribing(False)
                    if self.btn_transcribe:
                        self.btn_transcribe.config(text="▶  Iniciar Transcrição")

                self.root.after(0, fail)

        threading.Thread(target=run, daemon=True).start()

    def _goto_ia(self):
        if not self.segments:
            messagebox.showwarning("Atenção", "Transcreva primeiro.")
            return
        self.nb.select(2)

    def _copy_prompt(self):
        p = self.box_prompt.get("1.0", "end-1c")
        if not p.strip():
            messagebox.showwarning("Atenção", "Prompt vazio. Transcreva primeiro.")
            return
        self.root.clipboard_clear()
        self.root.clipboard_append(p)
        messagebox.showinfo("Copiado!", "Cole no Claude.ai, ChatGPT ou outra IA.\nCopie o JSON e cole abaixo.")

    def _process_resp(self):
        resp = self.box_resp.get("1.0", "end-1c").strip()
        if not resp:
            messagebox.showwarning("Atenção", "Cole a resposta da IA primeiro.")
            return
        if not self.project_id:
            messagebox.showwarning("Atenção", "Nenhum projeto ativo.")
            return

        try:
            cuts = parse_ai_response(resp)
        except Exception as e:
            messagebox.showerror("Erro ao processar", str(e))
            return

        if not cuts:
            messagebox.showwarning("Atenção", "Nenhum corte válido encontrado.")
            return

        self._write_work_file("ai_response.json", resp)
        self._write_work_json("cuts_planned.json", cuts)
        self._save_state({
            "stage": "cuts_planned",
            "status": "ok",
            "cuts_count": len(cuts),
        })

        db.save_cuts(self.project_id, cuts)
        db.update_project_status(self.project_id, "cortes_prontos")
        self._draw_cuts(cuts)
        self.nb.select(3)

    def _draw_cuts(self, cuts: list):
        for w in self.cuts_frame.winfo_children():
            w.destroy()
        self.cut_vars = {}

        try:
            from viral_engine.archetypes import ARCHETYPES
            archetypes = ARCHETYPES
        except Exception:
            archetypes = {}

        for cut in cuts:
            cid = cut.get("id", cut.get("cut_index", 0))
            self._draw_cut_card(cut, cid, archetypes)

    def _draw_cut_card(self, cut: dict, cid, archetypes: dict):
        card = tk.Frame(self.cuts_frame, bg=BG3)
        card.pack(fill="x", pady=3, padx=2)
        var = tk.BooleanVar(value=True)
        self.cut_vars[cid] = var

        hdr = tk.Frame(card, bg=BG3)
        hdr.pack(fill="x", padx=10, pady=(8, 3))

        tk.Checkbutton(
            hdr,
            variable=var,
            bg=BG3,
            fg=WHT,
            selectcolor=ACC,
            activebackground=BG3,
            font=FNTB,
        ).pack(side="left")

        dur = cut["end"] - cut["start"]
        arch_id = cut.get("archetype", "")
        arch_info = archetypes.get(arch_id, {})
        emoji = arch_info.get("emoji", "✂️")
        title = cut.get("title") or cut.get("titulo") or "Corte"

        tk.Label(hdr, text=f"{emoji} {title}", bg=BG3, fg=WHT, font=FNTB).pack(side="left", padx=4)
        tk.Label(
            hdr,
            text=f"  {fmt_time(cut['start'])} → {fmt_time(cut['end'])}  ({fmt_time(dur)})",
            bg=BG3,
            fg=GRY,
            font=FNT,
        ).pack(side="left")
        tk.Label(
            hdr,
            text=f" {arch_id} ",
            bg=ACC,
            fg=WHT,
            font=("Segoe UI", 8, "bold"),
            padx=5,
            pady=1,
        ).pack(side="right")
        tk.Label(
            hdr,
            text=", ".join(cut.get("platforms", [])),
            bg=BG3,
            fg=YEL,
            font=("Segoe UI", 9),
        ).pack(side="right", padx=8)

        if cut.get("hook"):
            tk.Label(
                card,
                text=f"🎣  {cut['hook']}",
                bg=BG3,
                fg="#a5b4fc",
                font=FNT,
                wraplength=960,
                justify="left",
                anchor="w",
            ).pack(fill="x", padx=22, pady=2)
        if cut.get("reason"):
            tk.Label(
                card,
                text=f"💡  {cut['reason']}",
                bg=BG3,
                fg=GRY,
                font=FNT,
                wraplength=960,
                justify="left",
                anchor="w",
            ).pack(fill="x", padx=22, pady=(0, 8))
        tk.Frame(card, bg=BG, height=1).pack(fill="x")

    def _approve_all(self):
        for v in self.cut_vars.values():
            v.set(True)

    def _reject_all(self):
        for v in self.cut_vars.values():
            v.set(False)

    def _start_render(self):
        if self.rendering:
            return

        if not self.project_id:
            messagebox.showwarning("Atenção", "Nenhum projeto ativo.")
            return

        all_cuts = db.get_cuts(self.project_id)
        approved = []
        for cut in all_cuts:
            cid = cut.get("id")
            idx = cut.get("cut_index", 0)
            key = cid if cid in self.cut_vars else idx
            if self.cut_vars.get(key, tk.BooleanVar(value=True)).get():
                if cid:
                    db.update_cut_status(cid, "aprovado")
                approved.append(cut)

        if not approved:
            messagebox.showwarning("Atenção", "Nenhum corte aprovado.")
            return

        if not self.project_root:
            self._infer_project_dirs(self.video_path)

        self._ensure_project_dirs()
        out_dir = self.output_dir
        os.makedirs(out_dir, exist_ok=True)

        self.nb.select(4)
        self.box_log.delete("1.0", "end")

        vaapi_ok = _detect_vaapi() and self.v_vaapi.get()
        self._log(f"Renderizando {len(approved)} cortes...")
        self._log(f"Saída: {out_dir}")
        self._log(f"Anti-copyright: {LEVEL_LABELS.get(self.v_ace.get(), '')}")
        self._log(f"Encoder: {'VA-API 2-pass ✅' if vaapi_ok else 'libx264 (CPU)'}\n")

        self._save_state({
            "stage": "render_started",
            "status": "running",
            "approved_cuts": len(approved),
            "output_dir": out_dir,
        })

        self._set_rendering(True)

        ace = self.v_ace.get()
        vaapi = self.v_vaapi.get()
        segs = self.segments
        vid = self.video_path
        pid = str(self.project_id)

        def run():
            try:
                for cut in approved:
                    title = cut.get("title") or cut.get("titulo")
                    if cut.get("archetype") and title:
                        try:
                            from viral_engine.hook_engine import ViralHookEngine
                            hook_data = ViralHookEngine().generate(
                                tema=title,
                                nicho="geral",
                                platform="tiktok",
                                archetype_id=cut["archetype"],
                            )
                            gancho = hook_data.get("gancho_final", "")[:50]
                            self.root.after(0, lambda m=f"🎯 Gancho: {gancho}": self._log(m))
                        except Exception:
                            pass

                self.root.after(0, lambda: self._log(f"Projeto raiz: {self.project_root}"))
                self.root.after(0, lambda: self._log(f"Work dir: {self.work_dir}"))

                results = render_all(
                    vid,
                    approved,
                    segs,
                    out_dir,
                    pid,
                    ace_level=ace,
                    use_vaapi=vaapi,
                    progress_cb=lambda m: self.root.after(0, lambda msg=m: self._log(msg)),
                )

                for cut_id, paths in results.items():
                    db.update_cut_output(cut_id, paths)

                db.update_project_status(self.project_id, "concluido")
                self._save_state({
                    "stage": "render_done",
                    "status": "ok",
                    "rendered_count": len(results),
                })

                gc.collect()

                def done():
                    self._log(f"\n✅ PRONTO! {len(results)} cortes em:\n{out_dir}")
                    self._set_rendering(False)
                    messagebox.showinfo("✅ Concluído", f"{len(results)} cortes gerados!\n\nPasta: {out_dir}")

                self.root.after(0, done)

            except Exception as e:
                err_msg = str(e)
                self._save_state({
                    "stage": "render_error",
                    "status": "error",
                    "error": err_msg,
                })

                def fail():
                    self._log(f"\n❌ ERRO: {err_msg}")
                    self._set_rendering(False)

                self.root.after(0, fail)

        threading.Thread(target=run, daemon=True).start()

    def _open_output(self):
        d = self.output_dir
        if d and os.path.exists(d):
            subprocess.Popen(["xdg-open", d])
        else:
            messagebox.showinfo("Info", "Pasta de saída ainda não criada.")

    def _generate_schedule(self):
        try:
            count = int(self.v_count.get())
            platform = self.v_platform.get()

            from anti_copy_modules.network_evasion import NetworkEvasion
            ne = NetworkEvasion(seed=int(datetime.now().timestamp()))
            schedule = ne.generate_schedule(count, platform)
            text = ne.format_schedule(schedule)

            try:
                from viral_engine.audience_analyzer import AudienceAnalyzer
                audience = AudienceAnalyzer().analyze("geral", platform)
                timing = audience.get("timing_otimo", [])
                if timing:
                    text += f"\n⏰ Melhores horários: {', '.join(timing)}"
            except Exception:
                pass

            self.box_agenda.delete("1.0", "end")
            self.box_agenda.insert("1.0", text)

        except ValueError:
            messagebox.showerror("Erro", "Quantidade inválida. Use número inteiro.")
        except Exception as e:
            messagebox.showerror("Erro", f"Erro ao gerar agenda: {e}")

    def _load_project(self):
        sel = self.tree.selection()
        if not sel:
            return

        pid = int(self.tree.item(sel[0])["values"][0])
        proj = db.get_project(pid)
        if not proj:
            return

        self.project_id = pid
        self.video_path = proj["video_path"]
        self._infer_project_dirs(self.video_path)
        self._ensure_project_dirs()

        t = db.get_transcription(pid)
        if t:
            self.segments = t["segments"]
            self.duration = self.segments[-1]["end"] if self.segments else 0
            self.box_transcript.delete("1.0", "end")
            for s in self.segments:
                self.box_transcript.insert("end", f"[{fmt_time(s['start'])}] {s['text']}\n")
            self.box_prompt.delete("1.0", "end")
            self.box_prompt.insert("1.0", build_analysis_prompt(self.segments, self.duration, ""))

        cuts = db.get_cuts(pid)
        if cuts:
            self._draw_cuts(cuts)

        self.v_name.set(proj["name"])
        self.lbl_video.config(text=f"✅ {os.path.basename(proj['video_path'])}", fg=GRN)
        messagebox.showinfo("Carregado", f"Projeto '{proj['name']}' carregado.\nStatus: {proj['status']}")
        self.nb.select(0)

    def _refresh_tree(self):
        for r in self.tree.get_children():
            self.tree.delete(r)
        for p in db.list_projects():
            self.tree.insert("", "end", values=(p["id"], p["name"], p["status"], p["created_at"]))

    # ── Helpers gerais ────────────────────────────────────────────────────────

    def _log(self, m):
        self.box_log.insert("end", m + "\n")
        self.box_log.see("end")

    def _status(self, m, color=GRY):
        self.lbl_status.config(text=m, fg=color)

    def _lbl(self, p, text="", font=None, color=None):
        return tk.Label(
            p,
            text=text,
            bg=p.cget("bg") if hasattr(p, "cget") else BG2,
            fg=color or WHT,
            font=font or FNT,
        )

    def _btn(self, p, text, cmd, color=BG3, wide=False):
        return tk.Button(
            p,
            text=text,
            command=cmd,
            bg=color,
            fg=WHT,
            font=FNTB,
            relief="flat",
            cursor="hand2",
            padx=20 if wide else 14,
            pady=8,
            activebackground=color,
            activeforeground=WHT,
            width=50 if wide else None,
        )

    def _chk(self, p, text, var):
        return tk.Checkbutton(
            p,
            text=text,
            variable=var,
            bg=p.cget("bg"),
            fg=WHT,
            selectcolor=ACC,
            activebackground=p.cget("bg"),
            font=FNT,
        )

    def _sep(self, p):
        tk.Frame(p, bg=BG3, height=1).pack(fill="x", padx=30, pady=16)
PYEOF

cat > run.sh <<'SHEOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -x "./venv/bin/python" ]]; then
  echo "Erro: venv não encontrado em ./venv"
  echo "Crie com: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
  exit 1
fi

exec ./venv/bin/python main.py
SHEOF

chmod +x run.sh

echo
echo "OK. Backup salvo em: $BACKUP_DIR"
echo "Arquivo atualizado: gui/main_gui.py"
echo "Arquivo atualizado: run.sh"
echo
echo "Agora rode:"
echo "  bash fix_clipfusion.sh"
echo "  ./run.sh"
EOF
