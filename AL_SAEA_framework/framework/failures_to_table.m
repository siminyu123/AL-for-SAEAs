function failureTable = failures_to_table(failures)
% Convert saved failure structs to a table.

if isempty(failures)
    failureTable = table();
    return;
end

n = numel(failures);
algorithm = strings(n,1);
problem = strings(n,1);
D = zeros(n,1);
run = zeros(n,1);
message = strings(n,1);
identifier = strings(n,1);
key = strings(n,1);

for i = 1:n
    f = failures{i};
    algorithm(i) = f.algorithm;
    problem(i) = f.problem;
    D(i) = f.D;
    run(i) = f.run;
    message(i) = f.message;
    identifier(i) = f.identifier;
    key(i) = f.key;
end

failureTable = table(algorithm, problem, D, run, message, identifier, key);
end
