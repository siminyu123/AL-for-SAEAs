function curve = best_curve_from_values(values)
% Convert exact objective values into a best-so-far curve.
% Only update when there is a better value. 
% Note: here only for minimization 
values = values(:)';
curve = zeros(size(values));
best = inf;
for i = 1:numel(values)
    if values(i) < best
        best = values(i);
    end
    curve(i) = best;
end
end
