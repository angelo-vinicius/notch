function descrever_sinal(x, t, truth, meta, titulo, xRef)
% DESCREVER_SINAL
%
% Mostra as caracteristicas do sinal testado e, se houver ambiente
% grafico, desenha dois ciclos com os entalhes destacados e um zoom no
% entalhe mais profundo.
%
%   descrever_sinal(x, t, truth, meta, titulo, xRef)
%
%   x, t, truth, meta : saidas de gerar_sinal_teste
%   titulo            : nome do sinal, para o texto e a figura
%   xRef              : (opcional) a mesma onda SEM entalhes, para
%                       comparacao no zoom

if nargin < 6, xRef = []; end

Fs  = meta.Fs;
f0  = meta.f0;
fR  = f0;                                    % frequencia REAL da rede
if isfield(meta, 'fReal'), fR = meta.fReal; end
nCic = numel(x)/(Fs/fR);

ent  = truth(strcmp({truth.tipo}, 'entalhe'));
prof = [ent.profundidade];
larg = [ent.tFim] - [ent.tInicio];
corte = (max(prof) + min(prof))/2;           % separa profundos de rasos
fundo = prof >= corte;

fprintf('\nSINAL TESTADO: %s\n', titulo);
fprintf('  taxa de amostragem ........ %g kS/s  (%.1f amostras por ciclo)\n', ...
        Fs/1e3, Fs/f0);
fprintf('  duracao ................... %.0f ciclos de %g Hz\n', nCic, fR);
fprintf('  conversor ................. 6 pulsos, alpha = %g graus, mu = %.1f graus\n', ...
        meta.alphaDeg, meta.muDeg);
fprintf('  divisor indutivo .......... rho = %.0f %%\n', 100*meta.rho);
fprintf('  entalhes no sinal ......... %d  (%.1f por ciclo)\n', ...
        numel(ent), numel(ent)/nCic);
fprintf('    profundos ............... %d, com %.1f V (%.1f %% do pico)\n', ...
        sum(fundo), median(prof(fundo)), 100*median(prof(fundo))/meta.Vpico);
if any(~fundo)
    fprintf('    rasos ................... %d, com %.1f V (%.1f %% do pico)\n', ...
            sum(~fundo), median(prof(~fundo)), 100*median(prof(~fundo))/meta.Vpico);
end
fprintf('  largura dos entalhes ...... %.0f us = %.1f amostras\n', ...
        1e6*median(larg), Fs*median(larg));

% ---------------- figura ----------------
try
    figure('Name', titulo, 'Color', 'w', 'Position', [80 60 1000 820]);
    azul = [0.12 0.31 0.55];  verm = [0.80 0.15 0.15];  lar = [0.97 0.75 0.55];
    roxo = [0.42 0.20 0.52];  verde = [0.09 0.55 0.45];
    % angulo da onda em cada instante (fase-fase: v_ab = ... sen(wt + 30))
    desloc = 30;
    if isfield(meta, 'Grandeza') && ~isempty(strfind(meta.Grandeza, 'neutro')), desloc = 0; end
    angulo = @(tt) mod(360*fR*tt + desloc, 360);

    % dois ciclos, pulando o primeiro (aquecimento do detector)
    n1  = round(Fs/fR);
    idx = (n1+1):min(numel(x), 3*n1);
    % entalhe para o zoom: o mais profundo, longe das bordas da janela
    folga  = 0.15*(t(idx(end)) - t(idx(1)));
    dentro = find([ent.tInicio] >= t(idx(1)) + folga & [ent.tFim] <= t(idx(end)) - folga);
    eZ = [];
    if ~isempty(dentro)
        [~, q] = max(prof(dentro));
        eZ = ent(dentro(q));
    end

    % ---------- (a) visao geral ----------
    subplot(2,1,1);
    hold on;
    if ~isempty(eZ)                                  % faixa do entalhe detalhado
        yl0 = 1.15*max(abs(x(idx)));
        fill(1e3*[eZ.tInicio eZ.tFim eZ.tFim eZ.tInicio], [-yl0 -yl0 yl0 yl0], lar, ...
             'EdgeColor', 'none');
    end
    hS = plot(1e3*t(idx), x(idx), 'Color', azul, 'LineWidth', 1);
    hR = [];
    for k = 1:numel(ent)
        j = (round(ent(k).tInicio*Fs)+1):(round(ent(k).tFim*Fs)+1);
        j = j(j >= idx(1) & j <= idx(end));
        if ~isempty(j)
            hR = plot(1e3*t(j), x(j), 'Color', verm, 'LineWidth', 2.2);
        end
    end
    % angulo de cada entalhe do primeiro ciclo mostrado
    yTop = 1.15*max(abs(x(idx)));
    for k = 1:numel(ent)
        tc = 0.5*(ent(k).tInicio + ent(k).tFim);
        if tc >= t(idx(1)) && tc <= t(idx(1)) + 1/fR
            text(1e3*tc, 0.93*yTop, sprintf('%.0f^\\circ', angulo(tc)), ...
                 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', verm);
        end
    end
    xlim(1e3*t(idx([1 end])));  ylim([-yTop yTop]);
    grid on;  box on;
    xlabel('t [ms]');  ylabel('v_{ab} [V]');
    title([titulo ' - entalhes em vermelho (numeros: angulo de cada entalhe na onda)']);

    % ---------- (b) anatomia do entalhe mais profundo ----------
    if ~isempty(eZ)
        mg = round(3e-4*Fs);
        i1 = round(eZ.tInicio*Fs)+1;  i2 = round(eZ.tFim*Fs)+1;
        jz = max(1, i1-mg):min(numel(x), i2+mg);
        jn = i1:i2;                                    % amostras do entalhe
        us = @(ii) 1e6*(t(ii) - eZ.tInicio);           % origem no inicio
        subplot(2,1,2);
        hold on;
        leg = {};  hL = [];
        temRef = ~isempty(xRef);
        tn = us(jn);  tn = tn(:)';  xn = x(jn);  xn = xn(:)';   % amostras do entalhe (linhas)
        if temRef
            rn = xRef(jn);  rn = rn(:)';
            r  = rn - xn;                              % residuo: referencia - sinal
            hA = fill([tn, fliplr(tn)], [xn, fliplr(rn)], lar, 'EdgeColor', 'none');
            hL(end+1) = hA;  leg{end+1} = 'area A (entre a onda sem entalhe e o sinal)';
            hX = plot(us(jz), xRef(jz), 'k--', 'LineWidth', 1.2);
            hL(end+1) = hX;  leg{end+1} = 'mesma onda sem entalhe (referencia)';
        end
        hS2 = plot(us(jz), x(jz), '.-', 'Color', azul, 'MarkerSize', 9, 'LineWidth', 0.8);
        plot(tn, xn, '.', 'Color', verm, 'MarkerSize', 12);
        hL(end+1) = hS2;  leg{end+1} = 'sinal testado (cada ponto e uma amostra)';
        yv  = x(jz);  yv = yv(:);
        if temRef, yr = xRef(jz);  yv = [yv; yr(:)]; end
        yv = yv(isfinite(yv));
        ymin = min(yv);  ymax = max(yv);  d = eZ.profundidade;
        ylim([ymin - 0.45*d, ymax + 0.45*d]);
        xlim(us(jz([1 end])));

        % profundidade
        if temRef
            [dmax, kk] = max(abs(r));
            xk = tn(kk);
            seta_dupla(xk, xn(kk), xk, rn(kk), roxo);
            text(xk + 8, 0.5*(xn(kk) + rn(kk)), 'profundidade d', ...
                 'Color', roxo, 'FontSize', 9, 'FontWeight', 'bold');
            areaA = trapz(abs(r))*1e6/Fs;
        else
            areaA = NaN;
        end
        % largura
        yw = ymin - 0.18*d;
        w  = 1e6*(eZ.tFim - eZ.tInicio);
        seta_dupla(0, yw, w, yw, verde);
        text(w/2, yw - 0.12*d, 'largura w', ...
             'Color', verde, 'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        % centro e angulo
        tcZ = 0.5*(eZ.tInicio + eZ.tFim);
        plot([1e6*(tcZ - eZ.tInicio)*[1 1]], [ymin - 0.05*d, ymax + 0.30*d], 'k:', 'LineWidth', 1);
        text(1e6*(tcZ - eZ.tInicio) + 6, ymax + 0.30*d, ...
             'centro t_c  \rightarrow  angulo \theta na onda', ...
             'FontSize', 9, 'VerticalAlignment', 'top');
        grid on;  box on;
        xlabel('t [us], origem no inicio do entalhe');  ylabel('v_{ab} [V]');
        title('Entalhe mais profundo: as grandezas que a cadeia mede (referencia = a mesma onda sem entalhe)');
        % a legenda vai para o canto esquerdo onde a onda NAO esta
        if x(jz(1)) < mean(ylim), locL = 'northwest'; else, locL = 'southwest'; end
        legend(hL, leg, 'Location', locL, 'FontSize', 8);
    end
    drawnow;
catch err
    fprintf('  (grafico nao exibido: %s)\n', err.message);
end
end

function seta_dupla(x1, y1, x2, y2, cor)
% seta com duas pontas, de (x1,y1) a (x2,y2), horizontal ou vertical
plot([x1 x2], [y1 y2], '-', 'Color', cor, 'LineWidth', 1.8);
if abs(x2 - x1) > abs(y2 - y1)                       % horizontal
    plot(min(x1,x2), y1, '<', 'Color', cor, 'MarkerFaceColor', cor, 'MarkerSize', 6);
    plot(max(x1,x2), y1, '>', 'Color', cor, 'MarkerFaceColor', cor, 'MarkerSize', 6);
else                                                 % vertical
    plot(x1, min(y1,y2), 'v', 'Color', cor, 'MarkerFaceColor', cor, 'MarkerSize', 6);
    plot(x1, max(y1,y2), '^', 'Color', cor, 'MarkerFaceColor', cor, 'MarkerSize', 6);
end
end
