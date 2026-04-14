VALIDAÇÃO DO PATCH — USO RÁPIDO

O que é .json?
- Um único documento JSON.

O que é .jsonl?
- JSON Lines.
- Cada linha é um JSON completo e independente.
- É melhor para histórico/registro contínuo, porque você pode ir adicionando uma linha por execução sem reescrever tudo.

Arquivos deste pacote:
- ops/manifests/patch_selecao_inteligencia_v1.json
- ops/validate_patch_and_register.py

Como instalar no repo:
1) copie a pasta ops/ para a raiz do projeto
2) rode:
   python3 ops/validate_patch_and_register.py ~/clipfusion

Saída esperada:
- STATUS: PASS
- caminho do relatório JSON em ops/reports/
- registro da execução em ops/patch_registry.jsonl
