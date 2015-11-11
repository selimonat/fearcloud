function [result,w] = svm_analysis_behavioral(analysis_type,data,labels)
%SVM_ANALYSIS allows different types of analysis classifying subjects,
%phases, conditions,...
%
%  [result] = SVM_ANALYSIS(analysis_type,data,labels) performs the analysis specified by ANALYSIS_TYPE.
%  You can choose from the following options:
%  1 - Classifies by SI (high=1 vs low=-1)
%  2 - Classifies by alpha before, phase 1 (low =1 vs high=-1 alpha) (good vs bad
%  discr)
% 
%
% SVM_ANALYSIS needs a datamatrix, e.g. containing trialloads,
% which can be found here:
% .../data/midlevel/singletrialfixmaps/trialload134dewhite.mat',
% as well as labels, found here:
% .../data/midlevel/singletrialfixmaps/labels.mat'

path = setPath;

r=0; %so far no randomization implemented

nbootstrap    = 100;
cmd           = '-t 0 -c 1 -q'; %t 0: linear, -c 1: criterion, -q: quiet
ids           = unique(labels.easy_sub);
nsub          = length(ids);
phases        = 1:5;
start_time    = [];%init variables here so that they are global
savepath      = [];
model         = [];

if analysis_type == 1
    name_analysis = 'subjects_by_SI_2class'; %classify subjects, collapse phases
    fprintf('Started analysis (%s): %s\n',datestr(now,'hh:mm:ss'),name_analysis);
    PrepareSavePath;
    ind = labels.phase == 4;
    result        = [];
    w             = [];
    for n = 1:nbootstrap
        Init;
        select    = logical(ismember(labels.SI2,[1 -1]).*ind);
        Y         = labels.SI2(select)';
        X         = data(select,:);
        P         = cvpartition(Y,'Holdout',.2); %prepares trainings vs testset
        %
        tic
        Classify;
        fprintf('Analysis: %s, Run %d - in %g seconds, cumulative time %g minutes...\n',name_analysis,n,toc,toc(start_time)/60);
        
        fprintf('===============\nFinished run %d in %g minutes...\n===============\n',n,toc(start_time)/60);
        result(:,:,n) = confusionmat(Real,Classified);
        w(:,n)          = model.SVs'*model.sv_coef;
    end
    
elseif analysis_type == 2
    name_analysis = 'subjects_by_alpha_bef_2class'; %classify subjects, collapse phases
    fprintf('Started analysis (%s): %s\n',datestr(now,'hh:mm:ss'),name_analysis);
    PrepareSavePath;
    ind = labels.phase == 1;
    result        = [];
    w             = [];
    for n = 1:nbootstrap
        Init;
        select    = logical(ismember(labels.alpha_bef2,[1 -1]).*ind);
        Y         = labels.alpha_bef2(select)';
        X         = data(select,:);
        P         = cvpartition(Y,'Holdout',.2); %prepares trainings vs testset
        %
        tic
        Classify;
         fprintf('Analysis: %s, Run %d - in %g seconds, cumulative time %g minutes...\n',name_analysis,n,toc,toc(start_time)/60);
        fprintf('===============\nFinished run %d in %g minutes...\n===============\n',n,toc(start_time)/60);
        result(:,:,n) = confusionmat(Real,Classified);
        w(:,n)          = model.SVs'*model.sv_coef;
    end
end


save(fullfile(savepath,'result.mat'),'result','model','w')

    function Classify
        model                           = svmtrain(Y(P.training), X(P.training,:), cmd);
        [predicted_label]               = svmpredict(Y(P.test), X(P.test,:), model);
        Classified                      = [Classified; predicted_label];
        Real                            = [Real;Y(P.test)];
    end
    function Init
        Classified = uint8([]);
        Real       = uint8([]);
        start_time = tic;
    end
    function PrepareSavePath
        savepath      = fullfile(path,[name_analysis '_rand' num2str(r),filesep]);
        if exist(savepath) == 0;mkdir(savepath);end
        fprintf('Created save path: %s\n',savepath);
    end

    function [path] = setPath
        if ispc || ismac
            [~,version] = GetGit(fileparts(which(mfilename)));
            path = fullfile(homedir,'Google Drive','EthnoMaster','data','midlevel','svm_analysis',['version' version]);
            mkdir(path)
            addpath([homedir '/Documents/Code/Matlab/libsvm/matlab'])
        elseif isunix
            [~,version] = GetGit(fullfile(homedir,'Documents','Code','Matlab','fearcloud'));
            path = fullfile(homedir,'Documents','fearcloud','data','midlevel','svm_analysis',['version' version]);
            mkdir(path)
            addpath([homedir '/Documents/Code/Matlab/libsvm/matlab'])
        end
    end

end
