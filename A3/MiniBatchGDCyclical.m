function [Wstar, bstar, J, l, accuracy, t, eta] = MiniBatchGDCyclical(X, Y, y, GDParams, NetParams, J, l, accuracy, t)

N = size(X.train, 2);

J_train = J.train; l_train = l.train;
J_val = J.val; l_val = l.val;
J_test = J.test; l_test = l.test;

setbreak = 0;
epoch = 0;
p = 0.8;

Wstar = cell(GDParams.n_cycles, numel(NetParams.W));
bstar = cell(GDParams.n_cycles, numel(NetParams.b));

old_l = 0;

while 1
    epoch = epoch + 1;
    
    random = randperm(size(X,2));
    X = X(:, random);
    Y = Y(:, random);
    
    for j=1:N/GDParams.n_batch
        
        GDParams.l = floor(t / (2 * GDParams.n_s));
        
        % Ensemble
        if GDParams.l > old_l 
            old_l = GDParams.l
                        
            Wstar(GDParams.l, :) = NetParams.W;
            bstar(GDParams.l, :) = NetParams.b;
            
            Params.W = Wstar;
            Params.b = bstar;
            
            accuracy.train_ensemble(GDParams.l) = ComputeMajorityVoteAccuracy(X.train, y.train, Params);
            accuracy.validation_ensemble(GDParams.l) = ComputeMajorityVoteAccuracy(X.val, y.val, Params);
            accuracy.test_ensemble(GDParams.l) = ComputeMajorityVoteAccuracy(X.test, y.test, Params);
        end
        
        if GDParams.l >= GDParams.n_cycles
            setbreak = 1;
            break;
        end
        
        if (t >= 2 * (GDParams.l) * GDParams.n_s) && (t <= (2 * (GDParams.l) + 1) * GDParams.n_s)
            eta_t = GDParams.eta_min + ((t - 2 * GDParams.l * GDParams.n_s) / GDParams.n_s) * (GDParams.eta_max - GDParams.eta_min);
        else 
            eta_t = GDParams.eta_max - ((t - (2 * GDParams.l + 1) * GDParams.n_s) / GDParams.n_s) * (GDParams.eta_max - GDParams.eta_min);
        end
    
        eta(t + 1) = eta_t;
        
        j_start = (j-1) * GDParams.n_batch + 1;
        j_end = j * GDParams.n_batch;
        inds = j_start:j_end;

        Xbatch = X.train(:, inds);
        Ybatch = Y.train(:, inds);
        
        [P, H] = EvaluatekLayer(Xbatch, NetParams);

%         H = EvaluateClassifier(Xbatch, W{1}, b{1}); H(H < 0) = 0;
        
        % Dropout
%         U = (rand(size(H)) < p) / p;
%         H = H .* U;
        
%         S = EvaluateClassifier(H, W{2}, b{2});
%         P = SoftMax(S);

        [gradW, gradb] = ComputeGradients(Xbatch, Ybatch, P, H, NetParams, GDParams.lambda);

        for i=1:numel(NetParams.W)
            NetParams.W{i} = NetParams.W{i} - eta_t * gradW{i};
            NetParams.b{i} = NetParams.b{i} - eta_t * gradb{i};
        end
        
        t = t + 1;
    end
    if setbreak == 1
        break;
    end

    [l_train(epoch + 1), J_train(epoch + 1)]  = ComputeCost(X.train, Y.train, NetParams, GDParams.lambda); 
    [l_val(epoch + 1), J_val(epoch + 1)] = ComputeCost(X.val, Y.val, NetParams, GDParams.lambda); 
    [l_test(epoch + 1), J_test(epoch + 1)] = ComputeCost(X.test, Y.test, NetParams, GDParams.lambda); 

    accuracy.train(epoch + 1) = ComputeAccuracy(X.train, y.train, NetParams);
    accuracy.validation(epoch + 1) = ComputeAccuracy(X.val, y.val, NetParams);
    accuracy.test(epoch + 1) = ComputeAccuracy(X.test, y.test, NetParams);
    epoch
end

J.train = J_train; l.train = l_train;
J.val = J_val; l.val = l_val;
J.test = J_test; l.test = l_test;

end