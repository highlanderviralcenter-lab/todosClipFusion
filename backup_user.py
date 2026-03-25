import os
import json
import shutil
import datetime
import subprocess
from pathlib import Path

def converter_bytes(tamanho_bytes):
    """Converte bytes para formato legivel"""
    for unidade in ['B', 'KB', 'MB', 'GB', 'TB']:
        if tamanho_bytes < 1024.0:
            return f"{tamanho_bytes:.2f} {unidade}"
        tamanho_bytes /= 1024.0
    return f"{tamanho_bytes:.2f} PB"

def mapear_diretorio(caminho):
    """Mapeia recursivamente um diretorio"""
    estrutura = []
    total_arquivos = 0
    total_diretorios = 0
    tamanho_total = 0
    
    try:
        for raiz, dirs, arquivos in os.walk(caminho):
            # Mapear diretorio atual
            caminho_rel = os.path.relpath(raiz, caminho)
            if caminho_rel == '.':
                caminho_rel = ''
            
            dir_info = {
                'tipo': 'diretorio',
                'caminho_relativo': caminho_rel,
                'caminho_completo': raiz,
                'nome': os.path.basename(raiz),
                'data_modificacao': datetime.datetime.fromtimestamp(os.path.getmtime(raiz)).isoformat(),
                'arquivos': []
            }
            
            total_diretorios += 1
            
            # Mapear arquivos neste diretorio
            for arquivo in arquivos:
                try:
                    caminho_arquivo = os.path.join(raiz, arquivo)
                    tamanho = os.path.getsize(caminho_arquivo)
                    tamanho_total += tamanho
                    
                    arquivo_info = {
                        'tipo': 'arquivo',
                        'nome': arquivo,
                        'caminho_relativo': os.path.join(caminho_rel, arquivo) if caminho_rel else arquivo,
                        'caminho_completo': caminho_arquivo,
                        'tamanho_bytes': tamanho,
                        'tamanho_human': converter_bytes(tamanho),
                        'extensao': os.path.splitext(arquivo)[1].lower(),
                        'data_modificacao': datetime.datetime.fromtimestamp(os.path.getmtime(caminho_arquivo)).isoformat()
                    }
                    dir_info['arquivos'].append(arquivo_info)
                    total_arquivos += 1
                except:
                    continue
            
            estrutura.append(dir_info)
    
    except Exception as e:
        print(f"Erro ao mapear: {e}")
    
    return estrutura, total_arquivos, total_diretorios, tamanho_total

def executar_robocopy(origem, destino):
    """Executa robocopy para copiar os arquivos"""
    print(f"\nIniciando robocopy de {origem} para {destino}")
    
    comando = [
        'robocopy',
        origem,
        destino,
        '/E',           # Inclui subdiretorios vazios
        '/COPYALL',     # Copia todas as informacoes
        '/R:3',         # 3 tentativas
        '/W:5',         # Espera 5 segundos
        '/NP',          # Sem porcentagem
        '/NDL',         # Sem lista de diretorios
        '/NJH',         # Sem cabecalho
        '/NJS',         # Sem resumo
        '/LOG+:D:\\robocopy_log.txt'  # Log detalhado
    ]
    
    try:
        resultado = subprocess.run(comando, capture_output=True, text=True, encoding='cp850')
        print("Robocopy concluido!")
        return resultado.returncode
    except Exception as e:
        print(f"Erro no robocopy: {e}")
        return -1

def main():
    # Configuracoes
    origem = r"C:\Users\Asus"
    destino = r"D:\procurando_projeto"
    json_nome = "mapeamento_completo.json"
    caminho_json_temp = r"C:\mapeamento_temp.json"
    caminho_json_final = os.path.join(destino, json_nome)
    
    print("=" * 60)
    print("MAPEAMENTO E COPIA DE ARQUIVOS")
    print("=" * 60)
    
    # Etapa 1: Mapear no SSD (C:)
    print(f"\nMapeando diretorio: {origem}")
    estrutura, total_arq, total_dir, tamanho_total = mapear_diretorio(origem)
    
    # Criar objeto final do JSON
    dados_json = {
        'metadados': {
            'data_geracao': datetime.datetime.now().isoformat(),
            'origem': origem,
            'destino': destino,
            'sistema_origem': 'Windows SSD (C:)',
            'sistema_destino': 'Disco D:'
        },
        'estatisticas': {
            'total_arquivos': total_arq,
            'total_diretorios': total_dir,
            'tamanho_total_bytes': tamanho_total,
            'tamanho_total_human': converter_bytes(tamanho_total)
        },
        'estrutura': estrutura
    }
    
    # Etapa 2: Salvar JSON temporario no C:
    print(f"\nSalvando mapeamento temporario: {caminho_json_temp}")
    try:
        with open(caminho_json_temp, 'w', encoding='utf-8') as f:
            json.dump(dados_json, f, indent=2, ensure_ascii=False)
        print(f"JSON temporario salvo: {converter_bytes(os.path.getsize(caminho_json_temp))}")
    except Exception as e:
        print(f"Erro ao salvar JSON: {e}")
        return
    
    # Etapa 3: Criar diretorio de destino se nao existir
    os.makedirs(destino, exist_ok=True)
    
    # Etapa 4: Executar robocopy
    retorno = executar_robocopy(origem, destino)
    
    # Etapa 5: Copiar JSON para destino
    if retorno >= 0:
        print(f"\nCopiando JSON para destino: {caminho_json_final}")
        try:
            shutil.copy2(caminho_json_temp, caminho_json_final)
            print(f"JSON copiado com sucesso!")
        except Exception as e:
            print(f"Erro ao copiar JSON: {e}")
    
    # Limpar arquivo temporario
    try:
        os.remove(caminho_json_temp)
        print(f"Arquivo temporario removido")
    except:
        pass
    
    # Resumo final
    print("\n" + "=" * 60)
    print("RESUMO FINAL")
    print("=" * 60)
    print(f"Origem: {origem}")
    print(f"Destino: {destino}")
    print(f"JSON gerado: {caminho_json_final}")
    print(f"Estatisticas:")
    print(f"   • Arquivos: {total_arq:,}")
    print(f"   • Diretorios: {total_dir:,}")
    print(f"   • Tamanho total: {converter_bytes(tamanho_total)}")
    print(f"   • Log do robocopy: D:\\robocopy_log.txt")
    print("=" * 60)
    print("Processo concluido com sucesso!")

if __name__ == "__main__":
    main()