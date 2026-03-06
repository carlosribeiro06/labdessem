using DataStructures
using JuMP

# ------------------------------------------------------------------------------
# Aliases de tipos
# ------------------------------------------------------------------------------

const KeyGEOL  = Tuple{Int, Int, String, String}
const KeyGT    = Tuple{Int, String, String}
const KeyUCT   = Tuple{Int, String, String}
const KeyYW    = Tuple{Int, String, String}

const KeyGH    = Tuple{Int, String, Int, Int, String}
const KeyTURB  = Tuple{Int, String, Int, Int, String}
const KeyUCH   = Tuple{Int, String, Int, Int, String}

const KeyV     = Tuple{Int, String, String}
const KeyINT   = Tuple{Int, String, String, String}

const KeyConstr = Tuple{Int, String, String}
const KeyUInt   = Tuple{Int, Int, Int, String}
const KeyWint   = Tuple{Int, Int, String}

# ------------------------------------------------------------------------------
# Tipos de configuração e estado do caso
# ------------------------------------------------------------------------------

"""
    CaseData

Estrutura com metadados do caso e flags (liga/desliga) de restrições,
cortes, rede, gráficos etc.

"""
mutable struct CaseData
    n_periodos::Int32
    n_term::Int32
    n_uhes::Int32
    Rest_Canal_Term::Int32
    Rest_Canal_Hid::Int32
    Rest_Bal_Hid::Int32
    Rest_Hid::Int32
    Rest_Limites_Fluxo::Int32
    Rest_Ton_Toff_Term::Int32
    Rest_Ton_Toff_Hid::Int32
    Rest_Inter::Int32
    Rest_Inter_Tabela::Int32
    Cortes::Int32
    Graficos::Int32
    Rede::Int32
    Defs::Int32

    function CaseData()
        new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    end
end

"""
    OtimizacaoConfig

Estrutura que armazena:
- `model::JuMP.Model`;
- dicionários de variáveis (indexados por chaves);
- referências de restrições (para consulta/atualização).

"""
mutable struct OtimizacaoConfig
    model::Model

    geol_vars::Dict{KeyGEOL, Any}
    gt_vars::Dict{KeyGT, Any}
    uct_vars::Dict{KeyUCT, Any}
    y_vars::Dict{KeyYW, Any}
    w_vars::Dict{KeyYW, Any}

    gh_vars::Dict{KeyGH, Any}
    turb_vars::Dict{KeyTURB, Any}
    uch_vars::Dict{KeyUCH, Any}

    vert_vars::Dict{KeyV, Any}
    vf_vars::Dict{KeyV, Any}

    alpha_vars::Any

    deficit_vars::Dict{KeyV, Any}
    excesso_vars::Dict{KeyV, Any}
    intercambio_vars::Dict{KeyINT, Any}

    constraint_dict::Dict{KeyConstr, ConstraintRef}
    constraint_balancDem_dict::Dict{KeyConstr, ConstraintRef}

    uint::Dict{KeyUInt, Any}
    wint::Dict{KeyWint, Any}

    function OtimizacaoConfig()
        new(
            Model(),
            Dict{KeyGEOL, Any}(),              # geol_vars
            Dict{KeyGT, Any}(),                # gt_vars
            Dict{KeyUCT, Any}(),               # uct_vars
            Dict{KeyYW, Any}(),                # y_vars
            Dict{KeyYW, Any}(),                # w_vars
            Dict{KeyGH, Any}(),                # gh_vars
            Dict{KeyTURB, Any}(),              # turb_vars
            Dict{KeyUCH, Any}(),               # uch_vars
            Dict{KeyV, Any}(),                 # vert_vars
            Dict{KeyV, Any}(),                 # vf_vars
            0,                                 # alpha_vars
            Dict{KeyV, Any}(),                 # deficit_vars
            Dict{KeyV, Any}(),                 # excesso_vars
            Dict{KeyINT, Any}(),               # intercambio_vars
            Dict{KeyConstr, ConstraintRef}(),  # constraint_dict
            Dict{KeyConstr, ConstraintRef}(),  # constraint_balancDem_dict
            Dict{KeyUInt, ConstraintRef}(),    # uint (como no original)
            Dict{KeyWint, ConstraintRef}(),    # wint (como no original)
        )
    end
end

"""
    Output

Estrutura de saída (resultados) do modelo.

"""
mutable struct Output
    model::Model

    geol_vars::Dict{KeyGEOL, Any}
    gt_vars::Dict{KeyGT, Any}
    uct_vars::Dict{KeyUCT, Any}
    y_vars::Dict{KeyYW, Any}
    w_vars::Dict{KeyYW, Any}

    gh_vars::Dict{KeyGH, Any}
    turb_vars::Dict{KeyTURB, Any}
    uch_vars::Dict{KeyUCH, Any}

    vert_vars::Dict{KeyV, Any}
    vf_vars::Dict{KeyV, Any}

    alpha_vars::Any

    deficit_vars::Dict{KeyV, Any}
    excesso_vars::Dict{KeyV, Any}
    intercambio_vars::Dict{KeyINT, Any}

    constraint_dict::Dict{KeyConstr, Any}
    constraint_balancDem_dict::Dict{KeyConstr, Any}

    function Output()
        new(
            Model(),
            Dict{KeyGEOL, Any}(),   # geol_vars
            Dict{KeyGT, Any}(),     # gt_vars
            Dict{KeyUCT, Any}(),    # uct_vars
            Dict{KeyYW, Any}(),     # y_vars
            Dict{KeyYW, Any}(),     # w_vars
            Dict{KeyGH, Any}(),     # gh_vars
            Dict{KeyTURB, Any}(),   # turb_vars
            Dict{KeyUCH, Any}(),    # uch_vars
            Dict{KeyV, Any}(),      # vert_vars
            Dict{KeyV, Any}(),      # vf_vars
            0,                      # alpha_vars
            Dict{KeyV, Any}(),      # deficit_vars
            Dict{KeyV, Any}(),      # excesso_vars
            Dict{KeyINT, Any}(),    # intercambio_vars
            Dict{KeyConstr, Any}(), # constraint_dict
            Dict{KeyConstr, Any}(), # constraint_balancDem_dict
        )
    end
end

# ------------------------------------------------------------------------------
# Tipos de cadastro/configuração
# ------------------------------------------------------------------------------

"""
    SubmercadoConfigData

Configuração de submercado:
- nome, código
- custo de déficit
- vetor de demanda (por período)
"""
mutable struct SubmercadoConfigData
    nome::String
    codigo::Int32
    deficit_cost::Float64
    demanda::Vector{Float64}

    function SubmercadoConfigData()
        new("", 0, 0.0, [])
    end
end

"""
    EOLConfigData

Configuração de eólica: nome, posto, barra e submercado.
"""
mutable struct EOLConfigData
    nome::String
    posto::Int32
    barra::Int32
    submercado::Int32

    function EOLConfigData()
        new("", 0, 0, 0)
    end
end

"""
    UTEConfigData

Configuração de térmica (UTE), incluindo parâmetros de commitment.
Campos `acionamento` e `desligamento`.
"""
mutable struct UTEConfigData
    nome::String
    pmin::Float64
    pmax::Float64
    custo::Float64
    barra::Int32
    codigo::Int32
    ton::Int32
    toff::Int32
    stat_ini::Int32
    ton_toff_ini::Int32
    submercado::Int32
    acionamento::Vector
    desligamento::Vector

    function UTEConfigData()
        new("", 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, [], [])
    end
end

"""
    UHEConfigData

Configuração de usina hidrelétrica (UHE), incluindo parâmetros de volume,
tipo, jusante e coeficientes para FCF.
"""
mutable struct UHEConfigData
    codigo::Int32
    nome::String
    vini::Float64
    vmin::Float64
    vmax::Float64
    tipo::String
    jusante::Any
    conjunto::Vector
    posto::Int32
    coef_ang_fcf::Vector
    coef_lin_fcf::Vector

    function UHEConfigData()
        new(0, "", 0.0, 0.0, 0.0, "", "", [], 999, [], [])
    end
end

"""
    CONJ_MAQConfig

Configuração de conjunto de máquinas: código e lista de unidades.
"""
mutable struct CONJ_MAQConfig
    codigo::Int32
    unidades::Vector

    function CONJ_MAQConfig()
        new(0, [])
    end
end

"""
    UnidadeHidreletricaConfig

Configuração por unidade hidrelétrica (unidade geradora), incluindo
pmin/pmax, ton/toff, barra e submercado, turbinamento máximo e produtibilidade.
"""
mutable struct UnidadeHidreletricaConfig
    nome::String
    codigo::Int32
    pmin::Float64
    pmax::Float64
    ton::Int32
    toff::Int32
    stat_ini::Int32
    ton_toff_ini::Int32
    barra::Int32
    submercado::Int32
    turb_max::Float64
    produtibilidade::Float64

    function UnidadeHidreletricaConfig()
        new("", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    end
end

# ------------------------------------------------------------------------------
# Rede e cortes
# ------------------------------------------------------------------------------

"""
    Info_Linhas

Dados de linha:
- barras de/para, reatância, capacidade
- vetor de sensibilidade
"""
mutable struct Info_Linhas
    codigo::Int32
    barra_de::Int32
    barra_para::Int32
    reatancia::Float64
    capacidade::Float64
    linha_matriz_sensibilidade::Vector

    function Info_Linhas()
        new(0, 0, 0, 0.0, 0.0, [])
    end
end

"""
    Info_Barras

Dados de barra:
- código, nome, carga
- submercado e período
"""
mutable struct Info_Barras
    codigo::Int32
    nome::String
    carga::Float64
    submercado::Int32
    periodo::Int32

    function Info_Barras()
        new(0, "", 0.0, 0, 0)
    end
end

"""
    Violacao_Rede

Representa uma violação de rede (por período e linha) com valor associado.
"""
mutable struct Violacao_Rede
    periodo::Int32
    linha::Int32
    capacidade::Float64

    function Violacao_Rede()
        new(0, 0, 0.0)
    end
end

"""
    Alphas

Armazena cortes (alpha).
"""
mutable struct Alphas
    cortes::Any
    function Alphas()
        new([])
    end
end

"""
    FPHA

Estrutura associada ao corte FPHA.
"""
mutable struct FPHA
    corte::Int32
    usina::String
    RHS::Float64
    Fcorrec::Float64
    Varm_coef::Float64
    Qtur_coef::Float64
    Qlat_coef::Float64

    function FPHA()
        new(0, "", 0.0, 0.0, 0.0, 0.0, 0.0)
    end
end