function plot_ciclo_fase(tc, angMedido, angVerd, titulo)
% PLOT_CICLO_FASE
%
% Mostra o angulo de cada entalhe num ciclo trigonometrico, com o RAIO
% representando o TEMPO: os primeiros entalhes ficam perto do centro, os
% ultimos na borda.  Ao lado, o erro de cada entalhe ao longo do tempo.
%
%   plot_ciclo_fase(tc, angMedido, angVerd, titulo)
%
%   tc         instante de cada entalhe [s]
%   angMedido  angulo medido [graus]
%   angVerd    angulo verdadeiro [graus]
%   titulo     nome da figura
%
% COMO LER
%   No ciclo, cada entalhe aparece duas vezes: o angulo verdadeiro
%   (circulo vazio) e o medido (ponto cheio).  Como um conversor de
%   6 pulsos tem 6 entalhes por ciclo, os pontos formam 6 raios.
%   Se o erro ACUMULASSE com o tempo, os pontos medidos se afastariam dos
%   verdadeiros cada vez mais para fora, girando em espiral.  Se o erro e
%   constante, medido e verdadeiro seguem juntos ate a borda.
%
% Com muitos entalhes (registros longos), desenha uma amostra uniforme de
% ate 6000 deles; a tendencia e calculada com todos.
%
% Usa so comandos basicos (plot, text, subplot), sem polarplot, para
% funcionar no MATLAB e no Octave.

tc = tc(:)';  angMedido = angMedido(:)';  angVerd = angVerd(:)';
erro = mod(angMedido - angVerd + 180, 360) - 180;

% tendencia com TODOS os entalhes
p = polyfit(tc, erro, 1);

% para registros longos, desenha uma amostra uniforme de ate 6000 entalhes
% (a figura com centenas de milhares de pontos fica pesada e nao mostra
% nada a mais)
nMaxDesenho = 6000;
if numel(tc) > nMaxDesenho
    sel = unique(round(linspace(1, numel(tc), nMaxDesenho)));
    tc = tc(sel);  angMedido = angMedido(sel);  angVerd = angVerd(sel);
    erro = erro(sel);
end

% raio = tempo normalizado, afastado do centro para os pontos nao se
% amontoarem na origem
r = (tc - min(tc))/max(eps, max(tc) - min(tc));
r = 0.15 + 0.85*r;

figure('Name', titulo, 'Color', 'w');

% ---------------- ciclo trigonometrico ----------------
subplot(1, 2, 1);
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
hV = plot(r.*cosd(angVerd), r.*sind(angVerd), 'o', ...
          'Color', [0.2 0.2 0.2], 'MarkerSize', 6);
hM = plot(r.*cosd(angMedido), r.*sind(angMedido), '.', ...
          'Color', [0.15 0.35 0.75], 'MarkerSize', 10);
axis equal; axis off;
xlim([-1.25 1.25]); ylim([-1.25 1.25]);
legend([hV hM], {'verdadeiro', 'medido pela SWRDFT'}, 'Location', 'southoutside');
title({'Angulo de cada entalhe (graus)', ...
       'centro = inicio do registro, borda = fim'});

% ---------------- erro ao longo do tempo ----------------
subplot(1, 2, 2);
plot(tc, erro, '.', 'Color', [0.15 0.35 0.75], 'MarkerSize', 10);
hold on;
plot(tc, polyval(p, tc), 'r-', 'LineWidth', 1.5);
plot([min(tc) max(tc)], [0 0], 'k:');
grid on;
margem = max(3, 1.5*max(abs(erro)));
ylim([-margem margem]);
xlabel('tempo [s]');
ylabel('erro: medido - verdadeiro [graus]');
title({'Erro de cada entalhe ao longo do tempo', ...
       sprintf('tendencia: %+.4f graus por segundo', p(1))});
legend({'erro de cada entalhe', 'tendencia (reta ajustada)'}, ...
       'Location', 'southoutside');
end
