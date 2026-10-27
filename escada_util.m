function out = escada_util(acao, varargin)
% ESCADA_UTIL  Funcoes de apoio dos testes de escalabilidade.
%
%   crit = escada_util('criterios')        criterios de veredito (comuns
%                                          a todos os testes)
%   v    = escada_util('veredito', S, crit) classifica: OK, ATENCAO, QUEBROU
%   escada_util('cabecalho', titulo)       imprime o cabecalho da tabela
%   escada_util('linha', nome, S, v)       imprime uma linha de resultado
%
% Os criterios ficam aqui, num lugar so, para que todos os testes sejam
% julgados pela mesma regua.  Ajuste-os aqui se quiser.
%
% Ficam num arquivo proprio porque o MATLAB exige funcoes locais no FIM de
% um script e o Octave as exige ANTES do uso -- assim funciona nos dois.

out = [];
switch acao

    case 'criterios'
        % OK:       nenhum falso ou perdido, e P90 de profundidade e de
        %           area ate okP90 %
        % ATENCAO:  falsos + perdidos ate atenErros (fracao do total) e
        %           P90 ate atenP90 %
        % QUEBROU:  pior que isso
        out = struct('okP90', 5, 'okErros', 0, ...
                     'atenP90', 20, 'atenErros', 0.02);

    case 'veredito'
        [S, crit] = varargin{:};
        erros = (S.nFalsos + S.nPerdidos)/max(1, S.nVerd);
        p90 = max(S.prof(2), S.area(2));
        if S.nFalsos + S.nPerdidos <= crit.okErros && p90 <= crit.okP90
            out = 'OK';
        elseif erros <= crit.atenErros && p90 <= crit.atenP90
            out = 'ATENCAO';
        else
            out = 'QUEBROU';
        end

    case 'cabecalho'
        fprintf('\n%s\n', varargin{1});
        fprintf('%-14s | %5s %5s %5s %5s | %3s | %13s %13s %13s | %s\n', ...
                'cenario', 'verd', 'det', 'fals', 'perd', 'Np', ...
                'prof med/P90', 'area med/P90', 'larg med/P90', 'veredito');
        fprintf('%s\n', repmat('-', 1, 104));

    case 'linha'
        [nome, S, v] = varargin{:};
        fprintf('%-14s | %5d %5d %5d %5d | %3d | %+6.1f %5.1f  %+6.1f %5.1f  %+6.1f %5.1f | %s\n', ...
                nome, S.nVerd, S.nDet, S.nFalsos, S.nPerdidos, S.Np, ...
                S.prof, S.area, S.larg, v);

    otherwise
        error('escada_util:acao', 'Acao desconhecida: %s', acao);
end
end
