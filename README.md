# LabDESSEM

O **LabDESSEM** é um ambiente de desenvolvimento voltado para experimentação, estudo e implementação de metodologias e funcionalidades aplicadas ao despacho energético de sistemas elétricos de potência. O projeto foi desenvolvido utilizando a linguagem **Julia** e tem como inspiração o modelo **DESSEM**, utilizado na programação diária da operação do Sistema Interligado Nacional (SIN) no Brasil.

O objetivo principal deste repositório é servir como um **laboratório de modelagem computacional**, permitindo explorar estruturas de dados, formulações matemáticas e algoritmos de otimização aplicados ao planejamento da operação energética de curtíssimo prazo.

---

## Contexto

No setor elétrico brasileiro, o planejamento da operação do sistema ocorre em diferentes horizontes de tempo. Entre os modelos utilizados nesse processo, destaca-se o **DESSEM**, responsável pela programação diária da operação do sistema elétrico.

Esse tipo de problema envolve a determinação do despacho ótimo das usinas de geração considerando:

- Custos de geração
- Restrições operativas
- Limitações hidráulicas
- Restrições de transmissão
- Atendimento à demanda de energia

O **LabDESSEM** busca reproduzir e estudar metodologias em um ambiente de desenvolvimento simplificado, permitindo experimentação e evolução gradual da formulação do modelo.

---

## Objetivos do projeto

Este projeto foi desenvolvido com os seguintes objetivos:

- Criar um ambiente para **desenvolvimento de metodologias e funcionalidades relacionadas à programação diária da operação**.
- Explorar o uso da linguagem **Julia** para modelagem matemática.
- Servir como ferramenta de apoio para **estudos acadêmicos e pesquisa** em operação de sistemas elétricos.

---

## Tecnologias utilizadas

O projeto utiliza as seguintes tecnologias principais:

- **Julia** – Linguagem de programação científica de alto desempenho
- **JuMP** – Framework para modelagem de problemas de otimização matemática
- **HiGHS** – Solver de otimização utilizado para resolução do modelo
- Estruturas de dados em Julia para representação do sistema elétrico

---

## Estrutura do projeto

O repositório está organizado de forma modular para facilitar o desenvolvimento e a manutenção do código.
