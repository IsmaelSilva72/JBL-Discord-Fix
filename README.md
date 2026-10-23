# JBL Discord Fix

Corrige o problema de **audio abafado no Discord** ao usar fones Bluetooth JBL.

## O problema

Quando voce usa o microfone de um fone Bluetooth no Discord, o Windows troca do perfil **A2DP** (estereo, qualidade alta) para o perfil **HFP** (mono, qualidade de telefone). Isso causa:

- Audio abafado e com qualidade ruim
- Interferencia e ruido
- Som mono em vez de estereo

## A solucao

Este utilitario forca o Windows a usar:

- **Saida** → JBL Stereo (perfil A2DP = qualidade alta)
- **Microfone** → JBL Hands-Free (perfil HFP = so o mic)

E monitora continuamente: se o Windows trocar os perfis sozinho, o script corrige automaticamente.

## Arquivos

| Arquivo | Descricao |
|---|---|
| `JBL-Fix-Background.vbs` | Inicia o monitor **sem janela**, com icone na bandeja do sistema. **Use este.** |
| `JBL-Discord-Fix.bat` | Inicia o monitor com janela CMD visivel (bom para debug). |
| `monitor-tray.ps1` | Monitor com icone na bandeja (usado pelo .vbs). |
| `monitor.ps1` | Monitor com saida no terminal (usado pelo .bat). |
| `audio-fix.ps1` | Versao com menu interativo para escolher dispositivos manualmente. |
| `fix-rapido.ps1` | Aplica o fix uma vez e mostra popup com resultado. |

## Como usar

### 1. Uso rapido

1. Conecte o fone JBL via Bluetooth
2. Clique duas vezes no **`JBL-Fix-Background.vbs`**
3. Um icone vai aparecer na bandeja do sistema (perto do relogio)
4. Pronto! O monitor esta rodando em segundo plano

### 2. No Discord

Depois de rodar o fix, confirme no Discord:

1. Abra **Configuracoes** → **Voz e Video**
2. **Dispositivo de entrada**: selecione o JBL (Hands-Free)
3. **Dispositivo de saida**: selecione o JBL (Stereo)

### 3. Icone na bandeja

Clique com o botao direito no icone para:

- **Aplicar fix agora** — forca a correcao manualmente
- **Sair** — para o monitor

O monitor mostra uma notificacao toda vez que corrige automaticamente.

### 4. Iniciar com o Windows (opcional)

Para que o fix rode automaticamente ao ligar o PC:

1. Aperte `Win + R`
2. Digite `shell:startup` e aperte Enter
3. Copie o arquivo `JBL-Fix-Background.vbs` para essa pasta (ou crie um atalho dele la)

Agora o monitor vai iniciar sozinho toda vez que voce ligar o computador.

## Solucao de problemas

### O audio ainda fica abafado

Alguns adaptadores Bluetooth nao conseguem manter os perfis A2DP e HFP ao mesmo tempo. Nesse caso:

1. Rode o `audio-fix.ps1` (menu interativo)
2. Escolha a opcao **[5]** para selecionar o microfone do notebook manualmente
3. No Discord, troque o dispositivo de entrada para o microfone do notebook

### O JBL nao aparece

- Verifique se o fone esta conectado via Bluetooth
- Abra **Configuracoes do Windows** → **Sistema** → **Som** e veja se o JBL aparece la
- Tente desconectar e reconectar o fone

### Erro de permissao ao rodar

Se o Windows bloquear a execucao do script:

1. Clique com o botao direito no arquivo `.vbs` ou `.bat`
2. Selecione **Propriedades**
3. Na aba Geral, marque **Desbloquear** (se aparecer)
4. Clique em **OK**

## Requisitos

- Windows 10 ou 11
- PowerShell 5.1+ (ja vem instalado no Windows)
- Fone Bluetooth JBL

## Como funciona (tecnico)

O script usa a **Windows Core Audio API** (COM interfaces `IMMDeviceEnumerator`, `IPolicyConfig`) para:

1. Listar dispositivos de audio ativos
2. Identificar o JBL Stereo (saida A2DP) e JBL Hands-Free (mic HFP)
3. Definir cada um como padrao para seu papel (saida/entrada)
4. Monitorar a cada 2 segundos se o Windows trocou os dispositivos
5. Corrigir automaticamente quando detecta a troca
