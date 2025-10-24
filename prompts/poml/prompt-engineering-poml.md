# Prompt Engineering para Devs + POML (guia prático)

## 1) Objetivo
Entregar um manual de uso direto para projetar, versionar e operar prompts em produtos. Foco: CoT, SoT, ToT, Self‑Consistency e POML.

---
## 2) Fundamentos rápidos
- **Role**: defina quem o modelo “é”.
- **Task**: descreva o que produzir.
- **Constraints**: limites, formatos, políticas.
- **I/O**: entradas estruturadas + saída determinística (JSON, Markdown, tabela).
- **Guardrails**: instruções para recusar e para rastrear incerteza.
- **Avaliação**: critérios, casos de teste, métricas simples (exatidão, cobertura, custo, latência).

> Regra: um prompt = um objetivo mensurável.

---
## 3) Tipos essenciais de prompts

### 3.1 Chain of Thought (CoT)
**Quando usar**: problemas com múltiplas etapas lógicas, matemática, planejamento.
**Risco**: vazamento de raciocínio para o usuário. Use versões “concise reasoning” ou “hidden CoT” quando não deve aparecer.
**Template**
```
Você é um solucionador metódico. Resolva passo a passo, validando cada etapa.
Entrada: <problema>
Saída: explique o raciocínio em etapas numeradas e conclua com "Resposta final: <...>".
```
**Dica**: limitar número de passos.

### 3.2 Skeleton of Thought (SoT)
**Quando usar**: resposta longa com estrutura previsível (artigos, relatórios, planos).
**Ideia**: gerar primeiro o esqueleto; depois expandir se aprovado.
**Template (fase 1)**
```
Gere apenas um esqueleto com seções e bullets para <tarefa>. Sem texto corrido.
```
**Template (fase 2)**
```
Expanda cada seção do esqueleto mantendo os bullets como subtítulos.
```

### 3.3 Tree of Thought (ToT)
**Quando usar**: exploração com múltiplas rotas (puzzles, design de API, estratégias).
**Ideia**: ramificar hipóteses, pontuar caminhos e escolher o melhor.
**Template**
```
Liste 3 abordagens alternativas para <tarefa>.
Para cada abordagem: passos, riscos, custo e nota 0–10.
Escolha a melhor e detalhe o plano.
```

### 3.4 Self‑Consistency
**Quando usar**: reduzir alucinação em questões abertas ou ruidosas.
**Ideia**: gerar N soluções independentes e votar/conciliar.
**Template orquestrador**
```
Execute o mesmo prompt base 5x com seeds/temperaturas diferentes.
Colete respostas, extraia consenso e reporte divergências.
```
**Saída final**: resposta + resumo do consenso + itens incertos.

---
## 4) Padrões práticos
- **Formatação**: peça JSON com schema fixo. Valide com JSON Schema.
- **Recuperação (RAG)**: separe instruções de contexto. Cite fontes.
- **Ferramentas**: especifique nomes, parâmetros e condições de uso.
- **Planos**: force DELIVERABLES, DEADLINES e OWNERS em listas.
- **Segurança**: defina conteúdos proibidos e estratégia de recusa.

---
## 5) POML em 12 linhas
**O que é**: Prompt Orchestration Markup Language. Linguagem tipo XML para declarar prompts, estilos, exemplos e entradas externas.
**Benefícios**
1. Prompts como código: versionamento, revisão e testes.
2. Separação de preocupações: instruções, estilos, dados e I/O.
3. Reuso: componentes e includes.
4. Execução previsível: renderiza para mensagens do provedor.

### 5.1 Estrutura mínima
```xml
<prompt>
  <role>Analista técnico objetivo.</role>
  <task>Gerar plano de testes para a feature X.</task>
  <constraints>
    <item>Resposta em JSON válido.</item>
    <item>Sem dados fictícios; marque lacunas.</item>
  </constraints>
  <output format="json">{
    "risks": [], "cases": [], "gaps": []
  }</output>
</prompt>
```

### 5.2 Incluindo dados externos
```xml
<documents>
  <file src="./docs/contrato.pdf" as="contrato" />
  <file src="./specs/api.yaml" as="openapi" />
</documents>
```
O motor POML injeta os conteúdos no contexto com rótulos.

### 5.3 Composições e estilo
```xml
<use style="./styles/pt_br_enterprise.poml" />
<examples src="./examples/test-plan/*.poml" />
```

---
## 6) Como POML ajuda no dia a dia
- **Multi‑cliente**: uma base de instruções, arquivos de estilo por cliente.
- **RAG**: templates padrão para consulta, citação e formatação de evidências.
- **Testes**: casos de input/expected guardados ao lado do template.
- **Observabilidade**: log do template + vars renderizadas para auditoria.

---
## 7) Integração no seu stack (.NET)

### Opção A: serviço fino de renderização
1. Guardar `.poml` no repositório.
2. Serviço Node/Python expõe `/render` que recebe `{ template, vars }` e devolve `messages`.
3. API .NET injeta dados, chama `/render`, envia `messages` ao provedor (OpenAI/Azure OpenAI).

**C# esqueleto**
```csharp
record LlmResult(string Content, double Cost);

var render = await http.PostAsJsonAsync("/render", new { template = "risk_plan.poml", vars });
var messages = await render.Content.ReadFromJsonAsync<List<Message>>();
var llm = await OpenAI.Chat.CreateAsync(model, messages);
```

### Opção B: CLI no build/CI
- Rodar um CLI que transforma `.poml` → `.json` e empacota com a aplicação.
- Vantagem: sem serviço extra em produção.

### Testes
- Guardar `fixtures/input.json` e `expected.json` por template.
- Teste .NET compara JSON normalizado e permite tolerâncias (ex.: ordem de arrays).

---
## 8) Snippets prontos

### CoT curto
```
Atue como verificador. Resolva em 3–6 passos e retorne:
{"steps": [..], "answer": "...", "confidence": 0–1}
```

### SoT para artigos técnicos
```
Gere apenas o esqueleto (títulos e bullets) para <tema>. Nada além do esqueleto.
```

### ToT para decisão de arquitetura
```
Forneça 3 alternativas. Para cada: arquitetura, trade‑offs, riscos, custo, nota 0–10.
Escolha uma e dê um plano em 5 passos.
```

### Self‑Consistency (orquestrador)
```
Execute o prompt base 5x (temperaturas variadas). Faça majority‑vote do campo "answer" e reporte divergências.
```

### POML + JSON fixo
```xml
<prompt>
  <role>Analista.</role>
  <task>Classificar tickets em categorias.</task>
  <output format="json">{"items": [{"id":"","category":"","rationale":""}]}</output>
  <constraints>
    <item>Use apenas: bug, feature, pergunta.</item>
  </constraints>
  <examples>
    <example input="Id=42; Texto='Erro 500'" output='{ "items":[{"id":"42","category":"bug","rationale":"HTTP 500"}] }' />
  </examples>
</prompt>
```

---
## 9) Boas práticas
- Inputs sempre estruturados (JSON ou campos nomeados).
- Conter o estilo: "curto", "sem opinião", "sem retórica".
- Versão e changelog do prompt.
- Tabelas de custo/latência no monitoramento.
- Feedback loop: amostras humanas rotuladas e testes de regressão.

### 9.1) Ajustes POML para eficiência máxima
- **Traga governança para o template**: use `<meta>` para versionar (`version`, `owner`, `updated`) e documentar decisões (`llm`, `temperature`, `maxTokens`). Isso permite auditar porque um prompt mudou.
- **Separação total de responsabilidades**: mantenha `<role>`, `<task>` e `<constraints>` focados no comportamento, e externalize tom/idioma via `<use style="..." />`. Evite repetir instruções de estilo em múltiplos prompts.
- **Defina entradas explícitas**: padronize variáveis (`{{cliente}}`, `{{objetivo}}`) e registre-as em comentários ou bloco auxiliar `<notes>`; combine com JSON de entrada validado. Falhas em prompts costumam vir de lacunas ou nomes ambíguos.
- **Especifique saídas verificáveis**: mantenha `<output format="json">` com schemas concretos e valide via testes automatizados antes de subir alterações.
- **Instrumente sinais de qualidade**: registre no `<meta>` os limites de custo/latência esperados e exponha via monitoramento; gere alertas quando um run extrapolar o previsto.
- **Inclua exemplos minimamente suficientes**: em vez de listas extensas, mantenha 2–3 `<example>` cobrindo happy path, edge case e falha esperada. Isso acelera o parse mental do modelo.
- **Padronize mensagens de recusa**: centralize guardrails (conteúdos proibidos, limites legais) em um arquivo de estilo e apenas aponte com `<use style>`. Reduz divergências entre prompts.
- **Automatize cenários de teste**: para cada `.poml`, mantenha fixtures contendo `input.json`, `expected.json` e scripts de regressão (ver seção 7). Erros recorrentes vêm da ausência de regression testing.
- **Itere com telemetria real**: colete respostas do modelo, avalie contra métricas (`accuracy`, `latency`, `cost`) e retroalimente o template. Falhas persistem quando melhorias ficam só no papel.

| Falha comum (Medium POML review) | Ajuste recomendado |
| --- | --- |
| Prompts genéricos que misturam tarefas | Separe cada intenção em um `.poml` focado e use orquestrador para combinar outputs. |
| Ausência de contexto mínimo | Vincule `<documents>` ou injete variáveis obrigatórias; adicione asserts que recusem se vier vazio. |
| Output inconsistente | Defina schema em `<output>` e normalize com pós-processamento e testes. |
| Falta de feedback loop | Registre métricas em `<meta>` + dashboards, e rode avaliações periódicas. |
| Mudanças não rastreadas | Versione via Git + changelog no bloco `<meta>` com motivo da alteração. |

## 10) Anti‑padrões
- Prompts que pedem tudo ao mesmo tempo.
- Saídas livres sem schema.
- Contexto irrelevante no RAG.
- Falta de testes e versionamento.

---
## 11) Checklist de entrega
- [ ] Objetivo mensurável
- [ ] Tipo escolhido: CoT/SoT/ToT/Self‑Consistency
- [ ] Saída com schema fixo
- [ ] Casos de teste + expected automatizados
- [ ] `<meta>` com versionamento e telemetria alvo
- [ ] Observabilidade e custo monitorados
- [ ] Gate de qualidade no CI
- [ ] Guardrails centralizados em estilos reutilizáveis

---
## 12) Próximos passos
1. Selecionar um caso do seu produto e criar o primeiro `.poml`.
2. Implementar renderização via serviço fino ou CLI.
3. Adicionar 10 casos de teste e métricas no dashboard.
4. Escalar para múltiplos clientes com stylesheets.
5. Versionar a biblioteca interna em `.github/prompts/poml/`, mantendo styles reutilizáveis e fixtures de regressão por template.

---
## 13) Fontes e leituras
- Wei et al. (2022). *Chain-of-Thought Prompting Elicits Reasoning in Large Language Models* (arXiv:2201.11903).
- Wang et al. (2023). *Self-Consistency Improves Chain of Thought Reasoning in Language Models* (arXiv:2203.11171).
- Yao et al. (2023). *Tree of Thoughts: Deliberate Problem Solving with Large Language Models* (arXiv:2305.10601).
- *Skeleton-of-Thought: Large Language Models Can Do Parallel Decoding* (arXiv, 2023).
- Microsoft. *Prompt Orchestration Markup Language (POML)* – repositório oficial (microsoft/poml) e documentação.
- Microsoft Tech Community. *Introducing POML: prompts como código*.
