%% model Ratings as Gaussian

%%1500ms
p               = Project;
g1 = Group([6 7 9 10 11 12 13 14 15 16 17 18 19 20 21 22 24 25 26 28 30 33 34 35]);%people with acceptable fits for ratings and PMF
n1 = length(g1.ids);
CSP_subject = mean(g1.pmf.params1([1,3],1,:),1);
CSP_mean = mean(CSP_subject);
g1.getSI(3);
FWHM=[];
for i=1:length(g1.tunings{4}.singlesubject)
    FWHM(i,:)= [g1.tunings{3}.singlesubject{i}.Est(2) g1.tunings{4}.singlesubject{i}.Est(2)];
end
FWHM_mean = mean(FWHM,1);
AMPL=[];
for i=1:length(g1.tunings{4}.singlesubject)
    AMPL(i,:)= [g1.tunings{3}.singlesubject{i}.Est(1) g1.tunings{4}.singlesubject{i}.Est(1)];
end
AMPL_mean = mean(AMPL,1);

%%1500ms
p               = Project;
g2 = Group(Project.subjects_600); 
n2 = length(g2.ids);

