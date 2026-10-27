function [events, flag, xref, epsilon, info] = ...
    notch_detector(x, Fs, f0, N, Arel, varargin)
% NOTCH_DETECTOR
%
% Detector sequencial de entalhes de comutacao (notching), com
% reconstrucao da referencia por BANCO DE RESSONADORES.
%
% Mantem o MESMO NOME e a MESMA ASSINATURA da fonte original do projeto.
% Chamadas antigas continuam valendo:
%
%     [events, flag, xref, epsilon] = notch_detector(x, Fs, f0, N, Arel);
%
% ---------------------------------------------------------------------
% O QUE O DETECTOR FAZ
% ---------------------------------------------------------------------
% Percorre o sinal amostra por amostra (processamento causal).  Para cada
% amostra:
%   1. preve quanto o sinal DEVERIA variar, se fosse so a fundamental
%      (limiar epsilon);
%   2. mede quanto ele REALMENTE variou;
%   3. se a variacao e plausivel, aceita a amostra: xref(i) = x(i);
%   4. se nao e, rejeita a amostra e preenche o buraco com a forma de onda
%      que existiria sem a comutacao.
%
% xref serve a dois propositos: decidir a proxima amostra (realimenta
% dprev) e, no fim, medir o entalhe (residuo = xref - x).
%
% ---------------------------------------------------------------------
% POR QUE UM BANCO DE RESSONADORES
% ---------------------------------------------------------------------
% A versao original reconstruia com UM ressonador:
%
%     xref(i) = 2*cos(W0)*xref(i-1) - xref(i-2)
%
% que e um oscilador sintonizado em f0: reproduz exatamente UMA senoide.
% Numa rede real a tensao tem harmonicos de fundo (5a, 7a, 11a, 13a).
% Durante o entalhe o ressonador unico ignora esses harmonicos e o erro
% de referencia CRESCE com o tempo -- medido: 68 V de erro em 60 amostras
% para uma rede com 4 % de THD.  Ao fim do entalhe a referencia ja esta
% longe do sinal, dprev permanece alto, e a marcacao NAO TERMINA.
%
% Teste com referencia perfeita (oraculo) confirmou: trocando so a
% reconstrucao, o detector funciona ate 10 % de THD.  O limiar nao tinha
% culpa.  A causa unica era erro de modelo na reconstrucao.
%
% O banco usa um ressonador por ordem harmonica, somados:
%
%     y_h(i) = 2*cos(h*W0)*y_h(i-1) - y_h(i-2)
%     xref(i) = soma de y_h(i)
%
% Cada ressonador reproduz sua componente; a soma reproduz a onda
% distorcida completa.
%
% ---------------------------------------------------------------------
% SEMEADURA: AJUSTE HARMONICO EM JANELA
% ---------------------------------------------------------------------
% Cada ressonador precisa de amplitude e fase iniciais.  Elas sao
% estimadas por minimos quadrados sobre uma JANELA de amostras de xref
% imediatamente anterior ao entalhe.
%
% Por que janela, e nao duas amostras:  inferir uma senoide a partir de
% duas amostras ADJACENTES exige dividir por sin(W0) = 0,0038, e o ruido
% e amplificado ~185 vezes.  Com janela de MEIO CICLO a matriz fica com
% numero de condicao 1,0 e o ruido e ATENUADO ~10 vezes (sao centenas de
% equacoes para 10 incognitas).  Janela de um quarto de ciclo ja tem
% condicionamento 24: meio ciclo e o minimo viavel.
%
% Por que sobre xref, e nao sobre x:  xref ja contem os entalhes
% anteriores reconstruidos, entao a janela nunca le uma amostra deprimida
% por comutacao.  A referencia se autolimpa.
%
% So entram no ajuste amostras ja PROCESSADAS e ACEITAS (nao marcadas).
% Isso exclui o trecho de aquecimento -- copia crua de x, que pode conter
% entalhes -- e impede que uma reconstrucao imperfeita anterior contamine
% os ajustes seguintes.
%
% Logo apos o aquecimento ha poucas amostras validas, entao o ajuste e
% GRADUADO: banco completo se houver ao menos meia janela; so a
% fundamental se houver ao menos N/8; ressonador unico caso contrario.
% info.semeaduraBanco / Fundamental / Adjacente contam cada caso.
%
% ---------------------------------------------------------------------
% CORRECOES HERDADAS
% ---------------------------------------------------------------------
%   - piso de ruido no limiar: epsilon colapsa nos picos da onda, onde a
%     derivada da fundamental se anula;
%   - reancoragem apos MaxRun reconstrucoes seguidas;
%   - sigma pela MAD da SEGUNDA diferenca (a primeira e dominada pelo
%     proprio sinal em taxas altas);
%   - area em V*us por regra trapezoidal (unidade da IEEE 519);
%   - filtro de largura minima e maxima;
%   - events sempre com campos definidos.
%
% ---------------------------------------------------------------------
% PROTECAO CONTRA O FILTRO ANTI-ALIASING
% ---------------------------------------------------------------------
% Todo medidor real tem um filtro anti-aliasing.  O filtro tem sobressinal
% (~8 % num sinc janelado) e oscila antes e depois de cada borda.  Isso
% dispara marcacoes espurias e, sobretudo, faz o detector ACEITAR o corpo
% de alguns entalhes.  O patamar aceito entra na janela de semeadura, a
% referencia do entalhe seguinte sai enviesada, e a falha se propaga a
% cada meio ciclo, gerando "entalhes fantasmas" de dezenas de volts.
%
% Duas protecoes, ligadas por padrao, quebram essa propagacao:
%   AjusteRobusto  a semeadura usa pesos de Tukey e ignora amostras muito
%                  distantes do ajuste;
%   FecharLacunas  trechos aceitos curtos entre duas marcacoes saem da
%                  janela de ajuste.
% Juntas, levam a medicao ao mesmo nivel obtido com uma janela de ajuste
% perfeitamente limpa.  Nenhuma das duas sozinha basta.
%
% ---------------------------------------------------------------------
% LIMITACOES CONHECIDAS
% ---------------------------------------------------------------------
%   - so reproduz as ordens listadas em 'Ordens'.  Inter-harmonicos e
%     supraharmonicos reintroduzem erro de modelo;
%   - a decisao compara a VARIACAO BRUTA entre amostras com o incremento
%     esperado, nao o desvio em relacao ao valor previsto.  Por isso:
%       * entalhes rasos cujo degrau vai CONTRA a inclinacao da onda podem
%         ser capturados como uma unica amostra (o degrau e a onda se
%         cancelam);
%       * entalhes de ENTRADA GRADUAL (disparo proximo de zero,
%         retificador a diodos) nao sao vistos: o evento comeca na borda
%         abrupta de saida e mede o que vem DEPOIS do entalhe.
%     A semeadura robusta nao resolve isso; exige trocar a regra de
%     decisao por um teste de previsao;
%   - aquecimento: as primeiras max(N/2, Janela) amostras nao sao
%     examinadas.
%
% ENTRADAS
%   x    : sinal de TENSAO (vetor)
%   Fs   : taxa de amostragem [Hz]
%   f0   : frequencia fundamental nominal [Hz]
%   N    : amostras por ciclo (Fs/f0)
%   Arel : coeficiente de confiabilidade (tipico 2 a 4)
%
% PARES NOME/VALOR OPCIONAIS
%   'Ordens'       ordens harmonicas modeladas      (padrao [1 5 7 11 13])
%   'JanelaAjuste' amostras da janela de semeadura  (padrao round(N/2))
%   'Cnoise'       multiplo de sigma no limiar      (padrao 5)
%   'MaxRun'       reconstrucoes seguidas maximas   (padrao 1 ms)
%   'MinWidth'     largura minima do evento [s]     (padrao 3e-5)
%   'MaxWidth'     largura maxima do evento [s]     (padrao 4e-3)
%   'Sigma'        desvio do ruido; [] = estimar    (padrao [])
%   'AjusteRobusto' semeadura por minimos quadrados reponderados
%                  (Tukey); false = minimos quadrados comuns (padrao true)
%   'FecharLacunas' exclui da janela de semeadura lacunas aceitas mais
%                  curtas que isto [s], cercadas por marcacoes; 0 =
%                  desligado                        (padrao 1e-3)
%
% SAIDAS
%   events(k): startSample, endSample, startTime, endTime,
%              widthSamples, widthTime, area [V*us], maxDepth [V],
%              avgDepth [V], saturado (logico), semeadura (3 = banco
%              completo, 2 = so fundamental, 1 = ressonador unico)
%   flag, xref, epsilon
%   info: sigma, MaxRun, Janela, Ordens, nRejected, nSaturados,
%         flagFraction, iInicio

%% ---------------- opcoes ----------------
p = struct('Ordens', [1 5 7 11 13], 'JanelaAjuste', [], 'Cnoise', 5, ...
           'MaxRun', [], 'MinWidth', 3e-5, 'MaxWidth', 4e-3, 'Sigma', [], ...
           'AjusteRobusto', true, 'FecharLacunas', 1e-3);
for a = 1:2:numel(varargin)
    if ~isfield(p, varargin{a})
        error('notch_detector:badOption', 'Opcao desconhecida: %s', varargin{a});
    end
    p.(varargin{a}) = varargin{a+1};
end

x = x(:);
L = numel(x);

xref    = x;
flag    = false(L,1);
epsilon = nan(L,1);

Ts     = 1/Fs;
omega  = 2*pi*f0;
Omega0 = 2*pi*f0/Fs;

k1 = Ts*omega;
k2 = Ts^2*omega^2/2;

N4 = round(N/4);
N2 = round(N/2);
Nmin = 3;

if isempty(p.MaxRun),       p.MaxRun = max(4, round(1e-3*Fs)); end
if isempty(p.JanelaAjuste), p.JanelaAjuste = N2;               end

W      = p.JanelaAjuste;
ordens = p.Ordens(:)';
H      = numel(ordens);

%% ---------------- ruido ----------------
if isempty(p.Sigma)
    d2 = x(1:end-2) - 2*x(2:end-1) + x(3:end);
    sigma = 1.4826*median(abs(d2 - median(d2)))/sqrt(6);
else
    sigma = p.Sigma;
end

%% ---------------- banco de ressonadores ----------------
c2   = 2*cos(ordens*Omega0);          % coeficiente da recorrencia de cada ordem
sAnt = sin(-ordens*Omega0);           % para o estado em k = -1
cAnt = cos(ordens*Omega0);

yA = zeros(1, H);                     % y_h(i-1)
yB = zeros(1, H);                     % y_h(i-2)
nMin1 = max(8, round(N/8));           % minimo para ajustar so a fundamental
nMinH = max(4*H, round(W/2));         % minimo para ajustar o banco completo
nSemFund = 0;  nSoFund = 0;  nBanco = 0;
modoSem = zeros(L,1);                 % modo de semeadura no inicio de cada evento

%% ============================================================
%  Deteccao sequencial
%  ============================================================
iInicio = max(N2 + 2, W + 1);
run = 0;

for i = iInicio:L-1

    d3 = k1*abs(xref(i-N4)) + k2*abs(xref(i-N2));
    epsilon(i) = Arel*d3 + p.Cnoise*sigma;

    dprev = abs(x(i)   - xref(i-1));
    dnext = abs(x(i+1) - x(i));

    nNeighbor = 1;
    if dprev <= epsilon(i), nNeighbor = nNeighbor + 1; end
    if dnext <= epsilon(i), nNeighbor = nNeighbor + 1; end
    isCore = nNeighbor >= Nmin;

    if ~isCore && run < p.MaxRun

        flag(i) = true;

        if run == 0
            % ---- semeadura: ajuste harmonico em janela ----
            % So entram amostras (a) ja PROCESSADAS pelo laco e (b) ACEITAS,
            % isto e, nao marcadas.  A primeira condicao exclui o trecho de
            % aquecimento, que e copia crua de x e pode conter entalhes.  A
            % segunda impede que uma reconstrucao imperfeita anterior
            % contamine o ajuste -- sem ela, um erro inicial se propaga a
            % todos os eventos seguintes.
            jIni = max(iInicio, i - W);
            idxW = (jIni:(i-1))';
            excl = flag(idxW);
            if p.FecharLacunas > 0
                excl = fechar_lacunas(excl, round(p.FecharLacunas*Fs));
            end
            val  = idxW(~excl);
            nOk  = numel(val);

            % Quantas componentes da para estimar com seguranca depende de
            % quantas amostras validas existem.  Logo apos o aquecimento ha
            % poucas, entao o ajuste e graduado.
            if nOk >= nMinH
                usar = 1:H;                    % banco completo
                nBanco = nBanco + 1;
                modoSem(i) = 3;
            elseif nOk >= nMin1
                usar = find(ordens == 1);      % so a fundamental
                if isempty(usar), usar = 1; end
                nSoFund = nSoFund + 1;
                modoSem(i) = 2;
            else
                usar = [];                     % recorrencia original
                nSemFund = nSemFund + 1;
                modoSem(i) = 1;
            end

            yA = zeros(1, H);
            yB = zeros(1, H);

            if isempty(usar)
                % sem janela suficiente: ressonador unico, duas amostras
                yA(1) = xref(i-1);
                yB(1) = xref(i-2);
            else
                kk = val - (i-1);              % tempo relativo: k = 0 e i-1
                M  = zeros(nOk, 2*numel(usar));
                for q = 1:numel(usar)
                    hq = ordens(usar(q));
                    M(:, 2*q-1) = sin(hq*Omega0*kk);
                    M(:, 2*q)   = cos(hq*Omega0*kk);
                end
                c  = ajuste_robusto(M, xref(val), p.AjusteRobusto);
                ah = c(1:2:end)';
                bh = c(2:2:end)';
                yA(usar) = bh;                                    % k =  0
                yB(usar) = ah.*sAnt(usar) + bh.*cAnt(usar);       % k = -1
            end
        end

        % ---- um passo de cada ressonador ----
        yN = c2.*yA - yB;
        yB = yA;
        yA = yN;
        xref(i) = sum(yN);

        run = run + 1;
    else
        xref(i) = x(i);
        run = 0;
    end
end

%% ============================================================
%  Agrupamento em eventos
%  ============================================================
df = diff([0; double(flag); 0]);
starts = find(df ==  1);
ends   = find(df == -1) - 1;

events = struct('startSample',{},'endSample',{},'startTime',{}, ...
                'endTime',{},'widthSamples',{},'widthTime',{}, ...
                'area',{},'maxDepth',{},'avgDepth',{},'saturado',{}, ...
                'semeadura',{});
nRej = 0;
nSat = 0;
k = 0;

for m = 1:numel(starts)
    i1 = starts(m);
    i2 = ends(m);
    idx = i1:i2;
    Ns = numel(idx);
    widthTime = Ns/Fs;

    if widthTime < p.MinWidth || widthTime > p.MaxWidth
        nRej = nRej + 1;
        continue
    end

    residual = xref(idx) - x(idx);
    if Ns > 1
        area = trapz(abs(residual))*Ts*1e6;
    else
        area = abs(residual)*Ts*1e6;
    end

    sat = (Ns >= p.MaxRun);
    nSat = nSat + sat;

    k = k + 1;
    events(k).startSample  = i1;
    events(k).endSample    = i2;
    events(k).startTime    = (i1-1)/Fs;
    events(k).endTime      = (i2-1)/Fs;
    events(k).widthSamples = Ns;
    events(k).widthTime    = widthTime;
    events(k).area         = area;
    events(k).maxDepth     = max(abs(residual));
    events(k).avgDepth     = (area*1e-6)/widthTime;
    events(k).saturado     = sat;
    % 3 = banco completo; 2 = so a fundamental; 1 = ressonador unico.
    % Modos 1 e 2 ocorrem logo apos o aquecimento, quando ainda nao ha
    % amostras processadas suficientes para estimar todas as harmonicas.
    events(k).semeadura    = modoSem(i1);
end

info = struct('sigma', sigma, 'MaxRun', p.MaxRun, 'Janela', W, ...
              'Ordens', ordens, 'nRejected', nRej, 'nSaturados', nSat, ...
              'flagFraction', mean(flag), 'iInicio', iInicio, ...
              'semeaduraBanco', nBanco, 'semeaduraFundamental', nSoFund, ...
              'semeaduraAdjacente', nSemFund);
end


% =====================================================================
function c = ajuste_robusto(M, y, robusto)
% Minimos quadrados; se robusto, reponderados com pesos de Tukey
% (bisquare): amostras muito distantes do ajuste recebem peso zero.
% Protege a semeadura contra amostras contaminadas que escaparam da
% marcacao -- tipicamente o patamar de um entalhe engolido.
c = M \ y;
if ~robusto, return; end
for it = 1:6
    r = y - M*c;
    s = 1.4826*median(abs(r - median(r)));
    s = max(s, 1e-6*max(abs(y)) + eps);
    u = r/(4.685*s);
    w = (1 - u.^2).^2;
    w(abs(u) >= 1) = 0;
    if sum(w > 0) < 2*size(M,2) + 2
        return                          % amostras demais rejeitadas: mantem
    end
    sw = sqrt(w);
    c = (M .* sw) \ (y .* sw);
end
end


function m = fechar_lacunas(m, gmax)
% Marca como excluidas as lacunas de amostras ACEITAS com ate gmax
% amostras, cercadas por amostras MARCADAS dos dois lados.  Essas lacunas
% costumam ser o patamar de um entalhe cuja entrada e saida foram
% marcadas mas cujo corpo foi aceito.  So usa o passado: e causal.
m = m(:);
n = numel(m);
k = 1;
while k <= n
    if ~m(k)
        a = k;
        while k <= n && ~m(k), k = k + 1; end
        b = k - 1;
        if a > 1 && b < n && (b - a + 1) <= gmax
            m(a:b) = true;
        end
    else
        k = k + 1;
    end
end
end
