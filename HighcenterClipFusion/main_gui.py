from __future__ import annotations

import json
import os
import threading
import tkinter as tk
from datetime import datetime, timedelta
from pathlib import Path
from tkinter import filedialog, messagebox, scrolledtext, ttk

import db
from cut_engine import _detect_vaapi, render_cut
from decision_engine import evaluate_decision
from platform_engine import platform_fit_score
from segment import segment_by_pauses
from transcription_quality import score_transcription

BG = "#0d0d1a"
BG2 = "#151528"
BG3 = "#1e1e3a"
ACC = "#7c3aed"
GRN = "#22c55e"
RED = "#ef4444"
YEL = "#f59e0b"
WHT = "#f1f5f9"
GRY = "#64748b"
FNT = ("Segoe UI", 10)
FNTB = ("Segoe UI", 10, "bold")
FNTL = ("Segoe UI", 13, "bold")
MONO = ("Consolas", 9)


class HighcenterClipFusionGUI:
    def __init__(self):
        db.init_db()

        self.root = tk.Tk()
        self.root.title("✂ HighcenterClipFusion")
        self.root.geometry("1120x800")
        self.root.configure(bg=BG)

        self.project_id: int | None = None
        self.transcript_id: int | None = None
        self.video_path: str | None = None
        self.segments: list[dict] = []
        self.candidates: list[dict] = []
        self.output_dir: str | None = None

        self._build_ui()

    def run(self):
        self.root.mainloop()

    def _build_ui(self):
        hdr = tk.Frame(self.root, bg=ACC, height=54)
        hdr.pack(fill="x")
        tk.Label(hdr, text="✂ HighcenterClipFusion", font=("Segoe UI", 16, "bold"), bg=ACC, fg=WHT).pack(side="left", padx=20, pady=12)
        tk.Label(hdr, text=f"VA-API: {'ON' if _detect_vaapi() else 'OFF'}", font=FNT, bg=ACC, fg="#ddd6fe").pack(side="right", padx=16)

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

    def _tab_projeto(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="📁 Projeto")

        self._lbl(f, "Novo projeto", font=FNTL).pack(anchor="w", padx=30, pady=(28, 4))
        r1 = tk.Frame(f, bg=BG2)
        r1.pack(fill="x", padx=30, pady=6)
        self._lbl(r1, "Nome:").pack(side="left")

        self.v_name = tk.StringVar(value=f"Projeto {datetime.now().strftime('%d/%m %H:%M')}")
        tk.Entry(r1, textvariable=self.v_name, width=44, bg=BG3, fg=WHT, insertbackground=WHT, relief="flat", font=FNT).pack(side="left", padx=10)

        vr = tk.Frame(f, bg=BG2)
        vr.pack(fill="x", padx=30, pady=6)
        self._btn(vr, "📂 Selecionar vídeo", self._select_video, ACC).pack(side="left")
        self.lbl_video = self._lbl(vr, "Nenhum vídeo selecionado", color=GRY)
        self.lbl_video.pack(side="left", padx=14)

        self._lbl(f, "Cole uma transcrição com uma frase por linha (opcional).", color=GRY).pack(anchor="w", padx=30, pady=(10, 4))
        self.box_transcript_input = scrolledtext.ScrolledText(f, height=8, bg=BG3, fg=WHT, font=MONO, relief="flat", insertbackground=WHT)
        self.box_transcript_input.pack(fill="both", padx=30, pady=(0, 10))

        self._btn(f, "▶ Processar Segmentação", self._start_transcription, GRN, wide=True).pack(padx=30, pady=8)
        self.lbl_status = self._lbl(f, "", color=GRY)
        self.lbl_status.pack(padx=30, pady=4)

    def _tab_transcricao(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="📝 Transcrição")
        self._lbl(f, "Segmentos construídos", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        self.box_transcript = scrolledtext.ScrolledText(f, bg=BG3, fg=WHT, font=MONO, relief="flat", insertbackground=WHT)
        self.box_transcript.pack(fill="both", expand=True, padx=30, pady=12)
        self._btn(f, "▶ Gerar Prompt IA →", self._goto_ia, ACC, wide=True).pack(padx=30, pady=(0, 20))

    def _tab_ia(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="🤖 IA Externa")

        self._lbl(f, "Payload para IA", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        self.box_prompt = scrolledtext.ScrolledText(f, height=10, bg=BG3, fg="#a5b4fc", font=MONO, relief="flat", insertbackground=WHT)
        self.box_prompt.pack(fill="x", padx=30, pady=(4, 14))

        self._lbl(f, "Resposta IA (JSON)", font=FNTB).pack(anchor="w", padx=30)
        self.box_resp = scrolledtext.ScrolledText(f, height=12, bg=BG3, fg=GRN, font=MONO, relief="flat", insertbackground=WHT)
        self.box_resp.pack(fill="both", expand=True, padx=30, pady=4)

        self._btn(f, "✅ Processar resposta → Ver Cortes", self._process_resp, GRN, wide=True).pack(padx=30, pady=(4, 20))

    def _tab_cortes(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="✂ Cortes")

        self._lbl(f, "Cortes avaliados pela Regra de Ouro", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        self.cuts_box = scrolledtext.ScrolledText(f, bg=BG3, fg=WHT, font=MONO, relief="flat", insertbackground=WHT)
        self.cuts_box.pack(fill="both", expand=True, padx=30, pady=8)

        self._btn(f, "🎬 Renderizar cortes aprovados", self._start_render, ACC, wide=True).pack(padx=30, pady=(4, 20))

    def _tab_render(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="🎬 Render")

        self._lbl(f, "Log de render", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        self.box_log = scrolledtext.ScrolledText(f, bg=BG3, fg=GRN, font=MONO, relief="flat", insertbackground=WHT)
        self.box_log.pack(fill="both", expand=True, padx=30, pady=10)
        self._btn(f, "📂 Abrir pasta de saída", self._open_output, GRY, wide=True).pack(padx=30, pady=(0, 20))

    def _tab_historico(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="📋 Histórico")

        self._lbl(f, "Projetos", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        cols = ("ID", "Nome", "Status", "Criado em")
        self.tree = ttk.Treeview(f, columns=cols, show="headings", selectmode="browse")
        for c in cols:
            self.tree.heading(c, text=c)
            self.tree.column(c, width=220 if c != "ID" else 70)
        self.tree.pack(fill="both", expand=True, padx=30, pady=10)
        self._btn(f, "🔄 Atualizar", self._refresh_tree, ACC, wide=True).pack(padx=30, pady=(0, 20))
        self._refresh_tree()

    def _tab_agenda(self):
        f = tk.Frame(self.nb, bg=BG2)
        self.nb.add(f, text="📅 Agenda")

        self._lbl(f, "Agenda de Upload", font=FNTL).pack(anchor="w", padx=30, pady=(20, 4))
        self.box_agenda = scrolledtext.ScrolledText(f, bg=BG3, fg=GRN, font=MONO, relief="flat", insertbackground=WHT)
        self.box_agenda.pack(fill="both", expand=True, padx=30, pady=10)
        self._btn(f, "📅 Gerar Agenda", self._generate_schedule, ACC, wide=True).pack(padx=30, pady=(0, 20))

    def _select_video(self):
        path = filedialog.askopenfilename(title="Selecionar vídeo", filetypes=[("Vídeos", "*.mp4 *.mkv *.mov *.avi *.webm"), ("Todos", "*.*")])
        if path:
            self.video_path = path
            self.lbl_video.config(text=f"✅ {os.path.basename(path)}", fg=GRN)

    def _start_transcription(self):
        if not self.video_path:
            messagebox.showwarning("Atenção", "Selecione um vídeo primeiro.")
            return

        name = self.v_name.get().strip() or "Projeto sem nome"
        self.project_id = db.create_project(name, self.video_path)
        raw = self.box_transcript_input.get("1.0", "end-1c").strip()
        lines = [x.strip() for x in raw.splitlines() if x.strip()] or ["Trecho de fallback para análise local."]

        base_segments = []
        t = 0.0
        for line in lines:
            end = t + 3.0
            base_segments.append({"start": t, "end": end, "text": line})
            t = end

        self.segments = segment_by_pauses(base_segments, min_duration=18.0, max_duration=35.0, pause_threshold=0.5)
        if not self.segments:
            self.segments = [{"start": 0.0, "end": min(30.0, max(18.0, t)), "text": " ".join(lines)}]

        full_text = "\n".join(lines)
        quality = score_transcription(confidence=0.85, noise_level=0.15)
        self.transcript_id = db.save_transcription(self.project_id, full_text, self.segments, quality)
        db.update_project_status(self.project_id, "transcribed")

        self.box_transcript.delete("1.0", "end")
        for seg in self.segments:
            self.box_transcript.insert("end", f"[{seg['start']:.2f}-{seg['end']:.2f}] {seg['text']}\n")

        payload = {"segments": self.segments, "need": "Retorne JSON list com external_score [0..1] por segmento"}
        self.box_prompt.delete("1.0", "end")
        self.box_prompt.insert("1.0", json.dumps(payload, ensure_ascii=False, indent=2))

        self._status(f"Projeto #{self.project_id} pronto. Vá para IA Externa.", GRN)
        self.nb.select(1)
        self._refresh_tree()

    def _goto_ia(self):
        self.nb.select(2)

    def _process_resp(self):
        if not self.project_id or not self.transcript_id:
            messagebox.showwarning("Atenção", "Crie projeto e segmentação primeiro.")
            return

        raw = self.box_resp.get("1.0", "end-1c").strip()
        if not raw:
            messagebox.showwarning("Atenção", "Cole um JSON de resposta da IA.")
            return

        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                parsed = parsed.get("cuts", [])
            if not isinstance(parsed, list):
                raise ValueError("Resposta deve ser lista JSON")
        except Exception as err:
            messagebox.showerror("Erro JSON", str(err))
            return

        self.candidates = []
        self.cuts_box.delete("1.0", "end")

        for idx, item in enumerate(parsed):
            start = float(item.get("start", idx * 20.0))
            end = float(item.get("end", start + 25.0))
            text = str(item.get("text", "Trecho sem texto")).strip()
            ext = float(item.get("external_score", 0.5) or 0.5)
            local = float(item.get("local_score", 0.0) or 0.0)
            if local == 0.0:
                local = platform_fit_score(text, "tiktok")
            platform_fit = float(item.get("platform_fit", platform_fit_score(text, "tiktok")))
            tq = float(item.get("transcription_quality", 0.85))

            verdict = evaluate_decision(local, ext, platform_fit, tq)
            scores = {
                "hook": item.get("hook", 0.0),
                "retencao_estimada": item.get("retencao_estimada", item.get("retention_score", 0.0)),
                "moment": item.get("moment", 0.0),
                "shareability": item.get("shareability", 0.0),
                "local_score": local,
                "external_score": ext,
                "platform_fit": platform_fit,
                "transcription_quality": tq,
                "final_score": verdict.final_score,
            }
            cid = db.save_candidate(
                self.project_id,
                self.transcript_id,
                start,
                end,
                text,
                scores=scores,
                decision=verdict.decision,
            )

            for platform in ["tiktok", "reels", "shorts"]:
                db.save_cut(self.project_id, cid, platform, "basic", verdict.final_score, verdict.decision)

            row = {
                "id": cid,
                "start": start,
                "end": end,
                "text": text,
                "final_score": verdict.final_score,
                "decision": verdict.decision,
            }
            self.candidates.append(row)
            self.cuts_box.insert(
                "end",
                f"#{cid} [{start:.1f}-{end:.1f}] score={verdict.final_score:.3f} -> {verdict.decision}\n{text}\n\n",
            )

        db.update_project_status(self.project_id, "cuts_ready")
        self.nb.select(3)
        self._refresh_tree()

    def _start_render(self):
        if not self.project_id or not self.video_path:
            messagebox.showwarning("Atenção", "Projeto/vídeo não definidos.")
            return

        approved = [c for c in self.candidates if c["decision"] in {"approve", "review"}]
        if not approved:
            messagebox.showwarning("Atenção", "Sem cortes aprovados para render.")
            return

        proj = db.get_project(self.project_id)
        safe_name = "".join(ch for ch in (proj["name"] if proj else "projeto") if ch.isalnum() or ch in " _-").strip().replace(" ", "_")
        out_dir = str(Path(self.video_path).parent / f"highcenter_{safe_name}")
        os.makedirs(out_dir, exist_ok=True)
        self.output_dir = out_dir

        self.nb.select(4)
        self.box_log.delete("1.0", "end")
        self._log(f"Renderizando {len(approved)} cortes em {out_dir}")

        def run_render():
            try:
                for c in approved:
                    base = f"cut_{c['id']}"
                    paths = render_cut(
                        self.video_path,
                        c["start"],
                        c["end"],
                        out_dir,
                        base,
                        protection_level="basic",
                        subtitle_text=c["text"],
                    )
                    for platform, path in paths.items():
                        self._log(f"✅ {platform}: {path}")
                        cuts = db.list_cuts(self.project_id)
                        for cut_row in cuts:
                            if cut_row["candidate_id"] == c["id"] and cut_row["platform"] == platform:
                                db.update_cut_output(cut_row["id"], path, decision="done")
                db.update_project_status(self.project_id, "done")
                self._log("\n✅ Render finalizado.")
            except Exception as err:
                self.root.after(0, lambda err_obj=err: self._log_error(err_obj))

        threading.Thread(target=run_render, daemon=True).start()

    def _open_output(self):
        if self.output_dir and os.path.exists(self.output_dir):
            os.system(f'xdg-open "{self.output_dir}"')
        else:
            messagebox.showinfo("Info", "Pasta de saída ainda não criada.")

    def _generate_schedule(self):
        now = datetime.now()
        slots = [now + timedelta(hours=i * 3) for i in range(8)]
        self.box_agenda.delete("1.0", "end")
        for dt in slots:
            self.box_agenda.insert("end", f"- {dt.strftime('%Y-%m-%d %H:%M')}\n")

    def _refresh_tree(self):
        for row in self.tree.get_children():
            self.tree.delete(row)
        for p in db.list_projects():
            self.tree.insert("", "end", values=(p["id"], p["name"], p.get("status", "-"), p["created_at"]))

    def _log(self, msg: str):
        self.root.after(0, lambda: (self.box_log.insert("end", msg + "\n"), self.box_log.see("end")))

    def _log_error(self, err: Exception):
        self._log(f"❌ {err}")

    def _status(self, msg: str, color=GRY):
        self.lbl_status.config(text=msg, fg=color)

    def _lbl(self, parent, text="", font=None, color=None):
        return tk.Label(parent, text=text, bg=parent.cget("bg") if hasattr(parent, "cget") else BG2, fg=color or WHT, font=font or FNT)

    def _btn(self, parent, text, cmd, color=BG3, wide=False):
        return tk.Button(parent, text=text, command=cmd, bg=color, fg=WHT, font=FNTB, relief="flat", cursor="hand2", padx=20 if wide else 14, pady=8, activebackground=color, activeforeground=WHT, width=50 if wide else None)


if __name__ == "__main__":
    HighcenterClipFusionGUI().run()
