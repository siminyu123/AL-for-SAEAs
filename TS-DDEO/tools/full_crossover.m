%------------------------------------------------------------------------
% This code is part of the program that produces the results in the following paper:
% Huixiang Zhen, Wenyin Gong, Ling Wang, Fei Ming, and Zuowen Liao. "Two-stage Data-driven Evolutionary Optimization for High-dimensional Expensive Problems", IEEE Transactions on Cybernetics, accepted, 2021.
% You are free to use it for non-commercial purposes. However, we do not offer any forms of guanrantee or warranty associated with the code. We would appreciate your acknowledgement.
%----------------------------------------------------------------------------------------------------------------------------------------

% full_crossover
% After the variable sequence is iterated completely, all
% decision variables of xbest are obtained by FC with
% all populations.
function [U] = full_crossover(F, hisx)
    [NP Dim] = size(hisx);
    pos0 = hisx(1,:);
    a = randperm(Dim);
    for i=1:Dim % iterates over all the decision variables
        k = a(i);
        pos = repmat(pos0,NP,1);
        pos(:,k) = hisx(:,k); % a temporary population whose k variable come from all individuals of P and other variables come from xbest
        fit = F(pos);
        [bestfit index] = min(fit);
        pos0(k) = hisx(index,k); % this dimension of xbest is replaced by the best individual
    end
    U = pos0;
end