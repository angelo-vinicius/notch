function P = parear_eventos(eventos, truth, tolS)
% PAREAR_EVENTOS
%
% Associa cada entalhe verdadeiro ao evento detectado mais proximo e
% devolve os erros EVENTO A EVENTO.
%
% Por que parear:  a populacao de entalhes de um conversor de 6 pulsos e
% BIMODAL -- 2 entalhes profundos e 4 com metade da profundidade por
% ciclo, na tensao fase-fase.  Comparar mediana medida contra mediana
% verdadeira, sem parear, e invalido: basta alguns eventos se
% fragmentarem ou fundirem para a mediana saltar de uma classe a outra.
% Isso chegou a produzir um "erro de +43 %" que, pareado, era -5,6 %.
%
% ENTRADAS
%   eventos : R.eventos (campos tInicio, tFim, maxDepth, width, area)
%   truth   : verdade de campo (campos tInicio, tFim, profundidade, area)
%   tolS    : tolerancia entre centros, usada quando nao ha
%             sobreposicao de intervalos [s]               (padrao 3e-4)
%
% SAIDA (struct P)
%   nVerd, nDet, nPareados, nFalsos, nPerdidos
%   eProf, eLarg, eArea : vetores de erro percentual, um por par
%   resumo : mediana e P90 do erro absoluto de cada grandeza
%   parEvento : para cada evento detectado, o indice do entalhe
%               verdadeiro com que foi pareado em P.entalhes (0 = falso)
%   entalhes  : os entalhes verdadeiros considerados (so os de tipo
%               'entalhe'), na ordem usada por parEvento
%
% REGRA DE PAREAMENTO
%   Para cada entalhe verdadeiro, o evento ainda livre de centro mais
%   proximo, entre os que se SOBREPOEM a ele no tempo ou cujo centro esta a
%   menos de tolS.  Cada evento serve a no maximo um entalhe.  Use
%   parEvento sempre que precisar saber quem ficou com quem (por exemplo,
%   para avaliar o angulo) -- assim toda a avaliacao usa a mesma regra.

if nargin < 3, tolS = 3e-4; end

ent = truth(strcmp({truth.tipo}, 'entalhe'));
cv  = 0.5*([ent.tInicio] + [ent.tFim]);

usado = false(1, numel(eventos));
parEvento = zeros(1, numel(eventos));
eProf = []; eLarg = []; eArea = [];

for j = 1:numel(ent)
    melhor = 0; dmin = inf;
    for k = 1:numel(eventos)
        if usado(k), continue; end
        ck = 0.5*(eventos(k).tInicio + eventos(k).tFim);
        d  = abs(ck - cv(j));
        % pareia se os INTERVALOS se sobrepoem, ou se os centros estao
        % proximos.  So a distancia de centros falha para entalhes largos
        % de entrada gradual (alpha ~ 0), em que o detector pega apenas a
        % borda de recuperacao e o centro detectado fica deslocado.
        sobrepoe = ~(eventos(k).tFim < ent(j).tInicio || ...
                     eventos(k).tInicio > ent(j).tFim);
        if (sobrepoe || d < tolS) && d < dmin
            dmin = d; melhor = k;
        end
    end
    if melhor > 0
        usado(melhor) = true;
        parEvento(melhor) = j;
        e  = eventos(melhor);
        lg = ent(j).tFim - ent(j).tInicio;
        eProf(end+1) = 100*(e.maxDepth - ent(j).profundidade)/ent(j).profundidade; %#ok<AGROW>
        eLarg(end+1) = 100*(e.width - lg)/lg;                                      %#ok<AGROW>
        if isfinite(ent(j).area) && ent(j).area > 0
            eArea(end+1) = 100*(e.area - ent(j).area)/ent(j).area;                 %#ok<AGROW>
        end
    end
end

P.nVerd     = numel(ent);
P.nDet      = numel(eventos);
P.nPareados = sum(usado);
P.nFalsos   = numel(eventos) - sum(usado);
P.nPerdidos = numel(ent) - sum(usado);
P.eProf = eProf;  P.eLarg = eLarg;  P.eArea = eArea;
P.parEvento = parEvento;
P.entalhes  = ent;

f = @(v) [mediana(v), p90abs(v)];
P.resumo = struct('prof', f(eProf), 'larg', f(eLarg), 'area', f(eArea));
end

function m = mediana(v)
if isempty(v), m = NaN; else, m = median(v); end
end

function q = p90abs(v)
% percentil 90 do erro ABSOLUTO: mede a dispersao que a mediana esconde
if isempty(v), q = NaN; return; end
a = sort(abs(v(:)));
q = a(max(1, ceil(0.9*numel(a))));
end
