function S = avaliar_cenario(opSinal, sementes, opAnalise)
% AVALIAR_CENARIO
%
% Roda a cadeia final sobre um cenario, repetindo para varias sementes de
% ruido, e devolve as metricas somadas.
%
%   S = avaliar_cenario(opSinal, sementes, opAnalise)
%
%   opSinal   : opcoes de gerar_sinal_teste, em cell  {'SNRdb', 55, ...}
%   sementes  : vetor de sementes                      [1 2 3]
%   opAnalise : opcoes extras de notch_analyze, em cell (opcional)
%
% Cada semente gera um sinal com o mesmo cenario mas outro sorteio de
% ruido.  Os erros evento a evento de todas as sementes sao reunidos antes
% de calcular mediana e P90, e as contagens sao somadas.
%
% O AQUECIMENTO e descontado: o detector so comeca depois de meio ciclo, e
% o banco de ressonadores so semeia com o modelo completo depois de mais
% meia janela.  Entalhes e eventos nesse trecho inicial ficam fora da
% avaliacao, para que ela meca o comportamento em regime.
%
% SAIDA (struct S)
%   nVerd, nDet, nFalsos, nPerdidos   contagens somadas
%   prof, larg, area                  [mediana P90] do erro pareado [%]
%   Np                                pulsos inferidos (o mais frequente)
%   amostrasPorEntalhe, sigma         informativos

if nargin < 3, opAnalise = {}; end

eP = []; eL = []; eA = [];
nV = 0; nD = 0; nF = 0; nPe = 0;
Np = zeros(1, numel(sementes));
sig = zeros(1, numel(sementes));
ape = NaN;

for k = 1:numel(sementes)

    [x, ~, truth, m] = gerar_sinal_teste(opSinal{:}, 'Semente', sementes(k));

    R = notch_analyze(x, m.Fs, m.f0, 'Vll', m.Vll, ...
                      'Grandeza', m.Grandeza, opAnalise{:});

    % fim do aquecimento: inicio do laco + meia janela de ajuste
    tCorte = (R.detector.iInicio + R.detector.Janela)/m.Fs;

    tr = truth([truth.tInicio] > tCorte);
    if isempty(R.eventos)
        ev = R.eventos;
    else
        ev = R.eventos([R.eventos.tInicio] > tCorte);
    end

    P = parear_eventos(ev, tr);

    nV  = nV  + P.nVerd;
    nD  = nD  + P.nDet;
    nF  = nF  + P.nFalsos;
    nPe = nPe + P.nPerdidos;
    eP  = [eP P.eProf];   %#ok<AGROW>
    eL  = [eL P.eLarg];   %#ok<AGROW>
    eA  = [eA P.eArea];   %#ok<AGROW>
    Np(k)  = R.conversor.pulsos;
    sig(k) = R.detector.sigma;
    ape    = m.amostrasPorEntalhe;
end

S.nVerd = nV;  S.nDet = nD;  S.nFalsos = nF;  S.nPerdidos = nPe;
S.prof = resumo(eP);
S.larg = resumo(eL);
S.area = resumo(eA);
S.Np = mode(Np);
S.sigma = mean(sig);
S.amostrasPorEntalhe = ape;
end


function r = resumo(v)
% [mediana, P90 do erro absoluto]
if isempty(v)
    r = [NaN NaN];
    return
end
a = sort(abs(v(:)));
r = [median(v), a(max(1, ceil(0.9*numel(a))))];
end
