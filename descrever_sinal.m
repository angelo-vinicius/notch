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
    figure('Name', titulo, 'Color', 'w');

    % dois ciclos, pulando o primeiro (aquecimento do detector)
    n1  = round(Fs/fR);
    idx = (n1+1):min(numel(x), 3*n1);

    subplot(2,1,1);
    plot(1e3*t(idx), x(idx), 'b'); hold on;
    for k = 1:numel(ent)
        j = (round(ent(k).tInicio*Fs)+1):(round(ent(k).tFim*Fs)+1);
        j = j(j >= idx(1) & j <= idx(end));
        if ~isempty(j)
            plot(1e3*t(j), x(j), 'r', 'LineWidth', 2);
        end
    end
    grid on; xlabel('t [ms]'); ylabel('v_{ab} [V]');
    title([titulo ' - entalhes em vermelho']);

    % zoom no entalhe mais profundo dentro da janela
    dentro = find([ent.tInicio] >= t(idx(1)) & [ent.tFim] <= t(idx(end)));
    if ~isempty(dentro)
        [~, q] = max(prof(dentro));
        e  = ent(dentro(q));
        mg = round(5e-4*Fs);
        jz = max(1, round(e.tInicio*Fs)+1-mg):min(numel(x), round(e.tFim*Fs)+1+mg);
        subplot(2,1,2);
        plot(1e6*(t(jz)-e.tInicio), x(jz), 'b', 'LineWidth', 1.5); hold on;
        if ~isempty(xRef)
            plot(1e6*(t(jz)-e.tInicio), xRef(jz), 'k--');
            legend('sinal testado', 'mesma onda sem entalhe', 'Location', 'best');
        end
        grid on; xlabel('t [us], origem no inicio do entalhe'); ylabel('V');
        title(sprintf('Zoom: entalhe profundo de %.0f V e %.0f us', ...
              e.profundidade, 1e6*(e.tFim-e.tInicio)));
    end
    drawnow;
catch err
    fprintf('  (grafico nao exibido: %s)\n', err.message);
end
end
