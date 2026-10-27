function d = difang(a, b)
% DIFANG  Diferenca angular a - b, em graus, no intervalo [-180, 180).
%   Evita que 359 graus contra 1 grau seja lido como 358 graus de erro.
d = mod(a - b + 180, 360) - 180;
end
