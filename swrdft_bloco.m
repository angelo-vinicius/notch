function [Ph, est] = swrdft_bloco(x, est)
% SWRDFT_BLOCO
%
% A mesma recursao da SWRDFT.m, para a fundamental (h = 1), aplicada a UM
% BLOCO do sinal e levando o estado para o bloco seguinte.  Processar um
% registro em blocos com esta funcao da exatamente o mesmo resultado que
% processa-lo inteiro com SWRDFT.m -- diferenca zero, conferida no teste 4.
%
%   est = struct('Nppc', N, 's1', 0, 's2', 1, 'Yc', 0, 'Ys', 0, ...
%                'buf', zeros(N,1), 'n', 0);      % antes do primeiro bloco
%   [Ph, est] = swrdft_bloco(x, est);             % para cada bloco
%
%   Ph  : fase da fundamental a cada amostra do bloco [rad], como a coluna
%         h = 1 da saida Ph de SWRDFT.m
%   est : estado da recursao
%           s1, s2   gerador recursivo de senos e cossenos
%           Yc, Ys   somas recursivas da janela
%           buf      ultimas Nppc amostras (as que vao saindo da janela)
%           n        amostras ja processadas
%
% POR QUE EXISTE
%   Em registros de minutos, o SWRDFT.m e lento (os vetores de saida crescem
%   dentro do laco) e calcula saidas que aqui nao sao usadas.  Esta funcao
%   pre-aloca o necessario e permite processar bloco a bloco, com memoria
%   que nao depende do tamanho do registro.

x  = x(:);
N  = est.Nppc;
w0 = 2*pi/N;
se = sin(w0);  co = cos(w0);

s1_0 = est.s1;  s2_0 = est.s2;
Yc = est.Yc;    Ys = est.Ys;
n0 = est.n;
xa = [est.buf; x];                 % ultimas N amostras do bloco anterior + bloco

Ph = zeros(numel(x), 1);
for j = 1:numel(x)
    s1 = co*s1_0 + se*s2_0;
    s2 = -se*s1_0 + co*s2_0;
    s1_0 = s1;  s2_0 = s2;
    if n0 + j > N
        xN = xa(j);                % amostra que sai da janela
    else
        xN = 0;
    end
    Yc = Yc + (x(j) - xN)*s2;
    Ys = Ys - (x(j) - xN)*s1;
    Ph(j) = atan2(Yc, -Ys) + w0;
end

est.s1 = s1_0;  est.s2 = s2_0;
est.Yc = Yc;    est.Ys = Ys;
est.buf = xa(end-N+1:end);
est.n   = n0 + numel(x);
end
