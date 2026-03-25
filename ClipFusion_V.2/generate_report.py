#!/usr/bin/env python3
"""
generate_report.py — Roda diariamente para gerar relatório ClipFusion Analytics.

Uso:
    python3 generate_report.py
    python3 generate_report.py --nicho tecnologia
    python3 generate_report.py --html ~/relatorios/hoje.html
    python3 generate_report.py --console
"""
import sys
import os
import argparse
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from analytics_engine import AnalyticsEngine


def main():
    parser = argparse.ArgumentParser(description="ClipFusion — Relatório diário de analytics")
    parser.add_argument("--nicho",   default="",    help="Filtrar por nicho")
    parser.add_argument("--html",    default="",    help="Salvar HTML em caminho")
    parser.add_argument("--console", action="store_true", help="Exibir no terminal")
    args = parser.parse_args()

    engine = AnalyticsEngine()

    # Caminho padrão para HTML se não especificado
    if not args.html and not args.console:
        ts = datetime.now().strftime("%Y-%m-%d")
        default_dir = Path.home() / ".clipfusion" / "reports"
        default_dir.mkdir(parents=True, exist_ok=True)
        args.html = str(default_dir / f"relatorio_{ts}.html")

    if args.console:
        print(engine.generate_report(nicho=args.nicho, console=True))
    else:
        html = engine.generate_report(nicho=args.nicho, output_html=args.html)
        print(f"✅ Relatório salvo em: {args.html}")
        print(f"   Tamanho: {len(html):,} bytes")

    # Sugestões sempre no terminal
    print("\n💡 Sugestões do sistema:")
    for s in engine.suggest_improvements(nicho=args.nicho):
        print(f"   → {s}")

    # A/B tests pendentes
    pending = engine.pending_ab_tests()
    if pending:
        print(f"\n⚗️  {len(pending)} teste(s) A/B pendente(s):")
        for t in pending:
            print(f"   #{t['id']} — {t['cut_id']} [{t['platform']}]")


if __name__ == "__main__":
    main()
