def suggest_secondary_audience(niche: str) -> str:
    return {
        "tecnologia": "produtividade",
        "fitness": "saúde",
        "investimentos": "empreendedorismo",
    }.get(niche, "geral")
