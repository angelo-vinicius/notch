function plot_ciclo_fase(tc, angMedido, angVerd, titulo, nCiclosJanela)
% PLOT_CICLO_FASE
%
% Mostra o angulo de cada entalhe num ciclo trigonometrico, com o RAIO
% representando o TEMPO: os primeiros entalhes ficam perto do centro, os
% ultimos na borda.  Ao lado, o MODULO DO ERRO DO ANGULO de cada entalhe,
% |medido - verdadeiro| em graus, no instante em que ele ocorreu, como um
% trem de impulsos (sempre positivo: mostra o tamanho do erro, nao o lado).
%
%   plot_ciclo_fase(tc, angMedido, angVerd, titulo, nCiclosJanela)
%
%   tc         instante de cada entalhe [s]
%   angMedido  angulo medido [graus]
%   angVerd    angulo verdadeiro [graus]
%   titulo     titulo geral, escrito no topo da figura (e nome da janela)
%   nCiclosJanela  quantos ciclos mostrar no trem de impulsos (padrao 3;
%              com o registro inteiro, os impulsos virariam um borrao)
%
% A frequencia f da rede (para a janela de nCiclosJanela ciclos) e obtida
% da propria inclinacao do angulo verdadeiro ao longo do tempo.
%
% COMO LER
%   No ciclo, cada entalhe aparece duas vezes: o angulo verdadeiro
%   (circulo vazio) e o medido (ponto cheio).  Como um conversor de
%   6 pulsos tem 6 entalhes por ciclo, os pontos formam 6 raios.
%   Se o erro ACUMULASSE com o tempo, os pontos medidos se afastariam dos
%   verdadeiros cada vez mais para fora, girando em espiral.  Se o erro e
%   constante, medido e verdadeiro seguem juntos ate a borda.
%
% Com muitos entalhes (registros longos), o ciclo desenha uma amostra
% uniforme de ate 360 deles; as estatisticas usam todos.
%
% Usa so comandos basicos (plot, text, subplot), sem polarplot, para
% funcionar no MATLAB e no Octave.

if nargin < 3
    error('plot_ciclo_fase:semDados', ['plot_ciclo_fase desenha dados calculados pelo teste 4 e precisa\n' ...
          'recebe-los; nao se roda sozinha.  Para gerar os graficos, rode\n' ...
          'teste_4_fase_swrdft.  Para redesenha-los a partir do resultado ja\n' ...
          'gravado, rode o teste 4 com soRedesenhar = true.']);
end

if nargin < 5 || isempty(nCiclosJanela), nCiclosJanela = 3; end
tc = tc(:)';  angMedido = angMedido(:)';  angVerd = angVerd(:)';
erro = mod(angMedido - angVerd + 180, 360) - 180;          % [graus]

% frequencia da rede: inclinacao do angulo verdadeiro ao longo do tempo
[tcs, ord] = sort(tc);
pf    = polyfit(tcs, unwrap(deg2rad(angVerd(ord))), 1);
fRede = pf(1)/(2*pi);


% janela do trem de impulsos: os primeiros nCiclosJanela ciclos
t0  = min(tc);
naJ = tc <= t0 + nCiclosJanela/fRede;
tJ  = tc(naJ);  eJ = abs(erro(naJ));      % modulo do erro [graus]

% para o ciclo, uma amostra uniforme de ate 360 entalhes (60 por raio):
% com marcadores finos e espacados, cada verdadeiro e cada medido aparecem
% separados (os calculos acima usam TODOS os entalhes)
nMaxDesenho = 360;
if numel(tc) > nMaxDesenho
    sel = unique(round(linspace(1, numel(tc), nMaxDesenho)));
    tcD = tc(sel);  angMD = angMedido(sel);  angVD = angVerd(sel);
else
    tcD = tc;  angMD = angMedido;  angVD = angVerd;
end

% raio = tempo normalizado, afastado do centro para os pontos nao se
% amontoarem na origem
r = (tcD - min(tcD))/max(eps, max(tcD) - min(tcD));
r = 0.15 + 0.85*r;

figure('Name', titulo, 'Color', 'w');

% ---------------- ciclo trigonometrico ----------------
ax1 = subplot(1, 2, 1);
pos = get(ax1, 'Position');               % abre espaco no topo para o titulo
set(ax1, 'Position', [pos(1) pos(2)*0.92 pos(3) pos(4)*0.86]);
hold on;
cinza = [0.85 0.85 0.85];
th = linspace(0, 2*pi, 361);
for rr = [0.25 0.5 0.75 1]
    plot(rr*cos(th), rr*sin(th), 'Color', cinza);
end
for a = 0:30:330
    plot([0 cosd(a)], [0 sind(a)], 'Color', cinza);
    text(1.13*cosd(a), 1.13*sind(a), sprintf('%d', a), ...
         'HorizontalAlignment', 'center', 'FontSize', 8);
end
hV = plot(r.*cosd(angVD), r.*sind(angVD), 'o', ...
          'Color', [0.25 0.25 0.25], 'MarkerSize', 3, 'LineWidth', 0.5);
hM = plot(r.*cosd(angMD), r.*sind(angMD), '.', ...
          'Color', [0.15 0.35 0.75], 'MarkerSize', 4);
axis equal; axis off;
xlim([-1.25 1.25]); ylim([-1.25 1.25]);
legend([hV hM], {'verdadeiro', 'medido pela SWRDFT'}, 'Location', 'southoutside');
title({'Angulo de cada entalhe (graus)', ...
       'centro = inicio do registro, borda = fim'});

% ---------------- trem de impulsos: modulo do erro do angulo ----------------
ax2 = subplot(1, 2, 2);
pos = get(ax2, 'Position');
set(ax2, 'Position', [pos(1) pos(2)*0.92 pos(3) pos(4)*0.86]);
hold on;
xI = 1e3*(tJ - t0);                       % um impulso por entalhe: linha de 0 ate o erro
plot([xI; xI], [zeros(size(eJ)); eJ], '-', 'Color', [0.15 0.35 0.75], 'LineWidth', 1.2);
plot(xI, eJ, 'o', 'Color', [0.15 0.35 0.75], 'MarkerFaceColor', [0.15 0.35 0.75], ...
     'MarkerSize', 4);
plot(1e3*[0, nCiclosJanela/fRede], [0 0], 'k-', 'LineWidth', 0.8);
grid on;
xlim(1e3*[0, nCiclosJanela/fRede]);
yMax = max(abs(eJ));  if yMax == 0, yMax = 1; end
if all(eJ >= 0), ylim([-0.15 1.3]*yMax); elseif all(eJ <= 0), ylim([-1.3 0.15]*yMax);
else, ylim(1.3*yMax*[-1 1]); end
xlabel(sprintf('tempo [ms]  (primeiros %d ciclos do registro)', nCiclosJanela));
ylabel('|erro| = |medido - verdadeiro| [graus]');
title({'Modulo do erro do angulo de cada entalhe', ...
       sprintf('registro inteiro: media %.2f, menor %.2f, maior %.2f graus', ...
               mean(abs(erro)), min(abs(erro)), max(abs(erro)))});

% ---------------- titulo geral, no topo da figura ----------------
% (o titulo tambem nomeia a janela, mas o nome da janela nao aparece na
% imagem gravada; escrito aqui, ele identifica a figura -- por exemplo, o
% nivel de ruido -- tambem no PNG)
if exist('sgtitle', 'file') || exist('sgtitle', 'builtin')
    sgtitle(titulo, 'FontWeight', 'bold', 'FontSize', 12);   % MATLAB R2018b ou mais novo
else
    axT = axes('Position', [0 0.955 1 0.04], 'Visible', 'off');
    text(0.5, 0.5, titulo, 'Parent', axT, 'Units', 'normalized', ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
         'FontWeight', 'bold', 'FontSize', 12);
end
end
