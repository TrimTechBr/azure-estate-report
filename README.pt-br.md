# AER — Azure Estate Report

> Dashboards HTML do seu ambiente Azure, somente leitura e 100% offline — gerados por um único comando PowerShell.

O **AER** é um módulo PowerShell 7 que conecta no Azure com as suas credenciais, coleta um inventário **somente leitura** do seu tenant através do **Azure Resource Graph** e das **APIs REST do ARM**, e gera um **relatório HTML autocontido** de várias páginas que você abre direto do disco — sem servidor web, sem banco de dados e sem precisar de internet para visualizar.

> 🌐 **English:** veja [README.md](README.md) (versão principal)

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Publish PowerShell Gallery](https://github.com/TrimTechBr/azure-estate-report/actions/workflows/publish-powershell-gallery.yml/badge.svg)](https://github.com/TrimTechBr/azure-estate-report/actions/workflows/publish-powershell-gallery.yml)
[![Somente leitura](https://img.shields.io/badge/modo-somente%20leitura-2ea44f)](#-seguran%C3%A7a--privacidade)
[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue)](#-licen%C3%A7a)

---

## ✨ Destaques

- **Um comando, o ambiente inteiro.** O `Invoke-AerReport` descobre todas as subscriptions que você tem acesso e produz um relatório completo.
- **100% somente leitura.** O AER nunca cria, altera ou exclui nada no Azure. Seguro para rodar em produção.
- **Saída totalmente offline.** O relatório é HTML/CSS/JS puro com os dados embutidos — compartilhe a pasta, abra numa máquina isolada, anexe a um chamado.
- **Exports executivos em XLSX e PDF.** A página inicial inclui botões para baixar um workbook Excel com dashboard rico e um PDF pronto para compartilhamento.
- **Rápido.** Os coletores rodam em paralelo no tenant.
- **UI moderna e navegável.** Experiência multi-página estilo SPA: menu lateral, tabelas com busca/filtros/redimensionamento, menus sanfona contextuais, gráficos de rosca/barras e diagramas interativos (topologia, peering, VM→DCR→destino) com zoom, arrasto e exportação PNG.

## 📊 O que tem no relatório

| Área | Páginas |
|------|---------|
| **Assessment** | Visão geral · Inventário de Recursos · Cloud Structure (management groups & subscriptions) · Azure Advisor |
| **Compute** | Virtual Machines · Virtual Machine Scale Sets |
| **Databases** | Visão geral · Relacionais (incl. SQL em VM) · NoSQL · Cache · Analytics · Table Storage |
| **Applications** | Visão geral · Web / App Services · Functions & Logic Apps · Containers · API & Integration · AKS |
| **Network** | Visão geral (utilização de IPs, DNS, balanceadores) · Virtual Networks (subnets, UDRs, diagrama de peering) · Load Balancers |
| **Observability** | Visão de cobertura · Diagnostic Settings · AMA & Data Collection (diagrama VM→DCR→destino) · Inventário (Log Analytics / App Insights) |
| **Policy** | Visão geral (compliance, assignments por efeito) · Exemptions · Remediation |
| **Security** | Defender for Cloud (cobertura de planos) · Recommendations |
| **Findings** | Otimização de custo · Recomendações de observabilidade · General (gaps de segurança/config) |

Toda tabela de dados tem busca global, filtros multi-seleção por coluna, ocultar/exibir colunas (persistido), redimensionamento de colunas, paginação e um menu sanfona de detalhes.

### Exports XLSX e PDF

Além do HTML offline, cada execução gera uma pasta `exports/` dentro do `-OutputPath`:

| Arquivo | Conteúdo |
|---------|----------|
| `exports/aer-report.xlsx` | Workbook Excel com primeira aba **Dashboard**, KPIs executivos, distribuição do estate, painéis de compute, sinais operacionais e abas técnicas/executivas para inventário, findings, Advisor, Defender, Policy, dados, aplicações e erros de coleta. |
| `exports/aer-report.pdf` | Relatório PDF em formato paisagem com capa executiva, métricas principais e páginas tabeladas para inventário, findings de segurança/custo e recomendações do Azure Advisor. |

Os links aparecem na página inicial do relatório HTML, no topo e no painel de export. Os arquivos são gerados localmente junto com o relatório e não dependem de serviços externos.

---

## 🖼️ Exemplos de saída

Você pode gerar um relatório local de exemplo sem conectar no Azure:

```powershell
Import-Module ./Aer.psd1 -Force
Invoke-AerReport -SampleData -OutputPath ./output-test/sample -OpenReport
```

### Assessment

| Visão geral | Inventário |
|-------------|------------|
| ![Visão geral do assessment](assets/images/assessment-overview.png) | ![Inventário de recursos](assets/images/assessment-inventory.png) |

| Cloud Structure | Azure Advisor |
|-----------------|---------------|
| ![Cloud structure](assets/images/assessment-cloudStructure.png) | ![Azure Advisor](assets/images/assessment-advisor.png) |

### Compute

| Virtual Machines | VM Scale Sets |
|------------------|---------------|
| ![Virtual Machines](assets/images/compute-vm.png) | ![Virtual Machine Scale Sets](assets/images/compute-vmss.png) |

### Databases

| Visão geral | Relacionais | NoSQL |
|-------------|-------------|-------|
| ![Visão geral de databases](assets/images/databases-overview.png) | ![Databases relacionais](assets/images/databases-relational.png) | ![Databases NoSQL](assets/images/databases-nosql.png) |

| Cache | Analytics | Table Storage |
|-------|-----------|---------------|
| ![Cache](assets/images/databases-cache.png) | ![Analytics](assets/images/databases-analytics.png) | ![Table Storage](assets/images/databases-tableStorage.png) |

### Applications

| Visão geral | Web / App Services | Functions & Logic |
|-------------|--------------------|-------------------|
| ![Visão geral de applications](assets/images/applications-overview.png) | ![Web e App Services](assets/images/applications-webapp.png) | ![Functions e Logic Apps](assets/images/applications-function.png) |

| Containers | API & Integration | AKS |
|------------|-------------------|-----|
| ![Containers](assets/images/applications-container.png) | ![API e Integration](assets/images/applications-api.png) | ![Clusters AKS](assets/images/applications-aks.png) |

### Network

| Visão geral | Virtual Networks | Load Balancers |
|-------------|------------------|----------------|
| ![Visão geral de network](assets/images/network-overview.png) | ![Virtual Networks](assets/images/network-vnet.png) | ![Load Balancers](assets/images/network-lbs.png) |

### Observability

| Visão geral | Diagnostic Settings |
|-------------|---------------------|
| ![Visão geral de observability](assets/images/observability-overview.png) | ![Diagnostic Settings](assets/images/observability-diagSettings.png) |

| AMA & Data Collection | Inventário |
|-----------------------|------------|
| ![AMA e Data Collection](assets/images/observability-ama-dcr.png) | ![Inventário de observabilidade](assets/images/observability-inventory.png) |

### Policy & Security

| Visão geral de Policy | Exemptions | Remediation |
|-----------------------|------------|-------------|
| ![Visão geral de Policy](assets/images/policy-overview.png) | ![Policy exemptions](assets/images/policy-exemption.png) | ![Policy remediation](assets/images/policy-remediation.png) |

| Visão geral de Security | Security Recommendations |
|-------------------------|--------------------------|
| ![Visão geral de Security](assets/images/security-overview.png) | ![Security recommendations](assets/images/security-recommendation.png) |

### Findings

| General | Cost | Observability |
|---------|------|---------------|
| ![Findings gerais](assets/images/findings-general.png) | ![Findings de custo](assets/images/findings-cost.png) | ![Findings de observabilidade](assets/images/findings-observability.png) |

---

## ✅ Requisitos

- **PowerShell 7.0+** (`pwsh`)
- **Módulos Az**: `Az.Accounts`, `Az.ResourceGraph`
- Uma **sessão Azure autenticada** (`Connect-AzAccount`)
- **RBAC no escopo alvo**:
  - `Reader` — mínimo, para o inventário e a maioria das páginas
  - `Monitoring Reader` — recomendado, para dados de observabilidade mais ricos
  - Para ler app settings de App Services (cobertura de App Insights) é necessário `Microsoft.Web/sites/config/list/Action` (ex.: *Website Contributor*); com *Reader* simples esse sinal é ignorado sem erro.

## 📦 Instalação

```powershell
# Clone o repositório
git clone https://github.com/TrimTechBr/azure-state-report.git
cd azure-state-report

# Instale as dependências do Azure (uma vez)
Install-Module Az.Accounts, Az.ResourceGraph -Scope CurrentUser

# Importe o módulo
Import-Module ./Aer.psd1
```

## 🚀 Começo rápido

```powershell
# 1) Autentique no Azure
Connect-AzAccount

# 2) Gere o relatório para todas as subscriptions acessíveis
Invoke-AerReport -OpenReport
```

O relatório é gravado em `.\aer-report\index.html` (mude com `-OutputPath`). O `-OpenReport` abre no navegador padrão ao terminar.

Os exports também ficam na mesma pasta: `.\aer-report\exports\aer-report.xlsx` e `.\aer-report\exports\aer-report.pdf`.

Para validar o layout sem acesso ao Azure, use a base de exemplo embutida:

```powershell
Invoke-AerReport -SampleData -OutputPath .\aer-sample -OpenReport
```

```
  AER · Azure Estate Report v0.1.0
  ──────────────────────────────────────────────
  ▶ Resolving Azure context…
  ✓ Signed in as voce@contoso.com  tenant: contoso.onmicrosoft.com
  ✓ 21 subscription(s) in scope
  ▶ Collecting estate data…  21 collectors · parallelism 4
  ✓ Collected all 21 data sets
  ▶ Rendering HTML report…
  ✓ Report generated  C:\...\aer-report\index.html
  ✓ Excel export      C:\...\aer-report\exports\aer-report.xlsx
  ✓ PDF export        C:\...\aer-report\exports\aer-report.pdf

  Summary
  ──────────────────────────────────────
    Subscriptions                    21
    Resource groups                 312
    Resources                     4,096
    ...
  ✓ Done.
```

## 🛠️ Uso

```powershell
# Todas as subscriptions do contexto atual
Invoke-AerReport

# Pasta de saída customizada + abrir ao terminar
Invoke-AerReport -OutputPath C:\Relatorios\Contoso -OpenReport

# Apenas subscriptions específicas
Invoke-AerReport -SubscriptionId '00000000-0000-0000-0000-000000000000','1111...'

# Excluir subscriptions por nome, com mais paralelismo
Invoke-AerReport -ExcludeSubscriptionName 'Sandbox','Lab' -MaxParallelCollectors 8

# Gerar um relatório de demo/layout com dados fake embutidos
Invoke-AerReport -SampleData -OutputPath .\aer-sample -OpenReport

# Capturar um objeto de sumário para automação
$r = Invoke-AerReport -PassThru
$r.Resources; $r.IndexHtml; $r.ExcelWorkbook; $r.PdfReport
```

### Parâmetros

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `-OutputPath` | string | `.\aer-report` | Pasta do relatório HTML (criada se não existir). Entrada: `index.html`. |
| `-SubscriptionId` | string[] | *(todas)* | Um ou mais IDs de subscription a incluir. |
| `-ExcludeSubscriptionName` | string[] | *(nenhuma)* | Nomes de subscription a excluir (exato, sem distinção de maiúsculas). |
| `-MaxParallelCollectors` | int (1–10) | `4` | Quantos coletores rodam em paralelo. |
| `-SampleData` | switch | off | Gera um relatório rico com dados fake sem conectar no Azure. Útil para screenshots, demos e validação de layout. |
| `-OpenReport` | switch | off | Abre o relatório no navegador ao terminar. |
| `-PassThru` | switch | off | Retorna um objeto de sumário (caminhos, contagens, duração). |

Ajuda completa no console:

```powershell
Get-Help Invoke-AerReport -Full
Get-Help Invoke-AerReport -Examples
```

---

## 🔒 Segurança & privacidade

- **Somente leitura por design.** O AER só faz chamadas de leitura/listagem/consulta (Resource Graph + ARM GET / `POST …/summarize|queryResults|list`). Nenhuma operação de escrita.
- **Seus dados ficam com você.** A coleta acontece localmente com as suas credenciais; o HTML embute os dados em `assets/data.js`. Nada é enviado para lugar nenhum.
- **Offline.** O relatório gerado não tem dependências externas e funciona sob `file://`.
- ⚠️ O relatório contém metadados do ambiente (nomes de recursos, IDs, configuração). Trate a pasta de saída como qualquer inventário de infraestrutura.

## 🧱 Arquitetura

```
Aer.psd1 / Aer.psm1          Manifest + loader do módulo (faz dot-source de tudo)
Public/Invoke-AerReport.ps1  Orquestrador (contexto → coleta paralela → render)
Core/ResourceGraph.ps1       Helper de query ARG, expansor de linhas columnar-safe, batch ARM, agregadores
Collectors/*.ps1             Uma função Get-Aer* por domínio → retorna um objeto simples
Renderer/
  Dashboard.ps1              Registro de páginas, menu lateral, scaffolds HTML por página, shell do documento
  Export.ps1                 Geração offline de XLSX/PDF e helpers OpenXML/PDF nativos
  Assets/Script.ps1          O app vanilla-JS (IIFE única) — tabelas, gráficos, diagramas
  Assets/Style.ps1           A folha de estilos
```

O fluxo: os **coletores** consultam o Azure e retornam objetos PowerShell → o orquestrador serializa em `window.AerData` → o **renderer** emite um HTML por página mais os `assets/` compartilhados (style.css, app.js, data.js) → o exportador cria `exports/aer-report.xlsx` e `exports/aer-report.pdf`. O JS lê o `AerData` e monta a UI no cliente.

---

## 🤝 Como contribuir

Contribuições são muito bem-vindas — novos coletores, páginas, checagens, correções e docs.

### Setup de desenvolvimento

```powershell
git clone https://github.com/TrimTechBr/azure-state-report.git
cd azure-state-report
Install-Module Az.Accounts, Az.ResourceGraph -Scope CurrentUser
Connect-AzAccount
Import-Module ./Aer.psd1 -Force
Invoke-AerReport -OutputPath ./output-test   # ./output-test está no .gitignore
```

> 💡 O PowerShell faz cache dos módulos importados. Após editar qualquer `.ps1`, rode `Import-Module ./Aer.psd1 -Force` (ou abra um terminal novo) antes de regenerar.

### Fluxo de branches & PR

1. Crie a branch a partir de `develop` (ex.: `feature-xxxx` / `fix-...`).
2. Faça commits objetivos.
3. Abra um Pull Request para `develop`. Mantenha o PR focado em uma feature/correção.
4. Descreva o que mudou e como você validou.

### Adicionando uma nova seção de domínio (o padrão)

1. **Coletor** — crie `Collectors/MinhaCoisa.ps1` com `Get-AerMinhaCoisa` retornando um `[pscustomobject]`.
2. **Conecte** em `Public/Invoke-AerReport.ps1` (quatro pontos): o array `$collectors`, o switch `$collectorFile`, o switch `$data` e a chave em `$reportData`.
3. **Página** — em `Renderer/Dashboard.ps1`: adicione uma entrada em `$script:AerPages`, um `navItem` no menu e um scaffold HTML em `Get-AerPageContent`.
4. **Render** — em `Renderer/Assets/Script.ps1`: leia `d.minhaCoisa` e monte a UI (reaproveite `initDataTable`, `renderDonut`, `renderBars`, `setHeader`, `kvGrid` e os helpers de pills).

### Convenções & armadilhas (aprendidas na prática)

- **Alvo PowerShell 7**; use apenas chamadas Azure de leitura.
- **Quirk columnar do ARG:** o `Search-AzGraph` pode, de forma intermitente, retornar um objeto *columnar* em vez de um objeto por linha. Para queries `project` só com colunas escalares, envolva o resultado com `Expand-AerRows` (em `Core/ResourceGraph.ps1`). Não use em queries que legitimamente retornam colunas com array.
- **Recursos em escopo de Management Group** (ex.: Policy assignments/exemptions) são **descartados** por uma query escopada em subscription — consulte o endpoint REST do ARG **sem** filtro de `subscriptions` (e `resultFormat=objectArray`) quando precisar do escopo de MG.
- **Palavras reservadas do KQL:** não use `kind` como coluna de saída do `project` (faça alias, ex.: `dcrKind = tostring(kind)`).
- **Variáveis automáticas do PowerShell:** nunca reutilize `$pid` ou `$host` como variáveis próprias (são read-only).
- **Arrays em JSON:** o `ConvertTo-Json` desempacota arrays de um elemento — o lado JS normaliza listas com `toArr()`; o `ConvertFrom-Json` do PS7 converte datas ISO automaticamente para `[datetime]` (formate com cuidado).
- **Batch ARM:** use `Invoke-AerArmBatch` (≤20 requisições por chamada) para REST por recurso (ex.: diagnostic settings).
- **Valide antes de commitar:**
  ```powershell
  [System.Management.Automation.Language.Parser]::ParseFile('caminho\arquivo.ps1',[ref]$null,[ref]([ref]$errs).Value)
  Import-Module ./Aer.psd1 -Force; Invoke-AerReport -OutputPath ./output-test
  ```

---

## 🗺️ Roadmap

- Mais páginas de Network (regras de NSG, route tables, Azure Firewall, public IPs)
- Páginas de detalhe por categoria para seções adicionais
- Publicação na PowerShell Gallery
- Exportação opcional em CSV dos dados coletados

## 📄 Licença

MIT © AER contributors. Veja [LICENSE](LICENSE).
