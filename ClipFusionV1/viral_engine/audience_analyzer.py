def infer_niche(context: str) -> str:
    text = context.lower()
    for n in ["investimentos", "fitness", "tecnologia", "relacionamentos", "empreendedorismo"]:
        if n in text:
            return n
    return "geral"
