function [tRise, tFall]  = ttlEdges(tsd,varargin)

thresh = 0.5;

process_varargin(varargin);

y = tsd.data';
t = tsd.range';

ind= y>thresh;
ind=[0, (diff(ind))>0 ];
tRise = t(ind==1);

ind= y>thresh;
ind=[0, (diff(ind))<0 ];
tFall = t(ind==1);


tFall = tFall(~isnan(tFall));
tRise = tRise(~isnan(tRise));

temp = y>thresh;
if temp(end)==1;
    tFall(end+1) = t(end);
end
if temp(1)==1;
    tRise = cat(2,t(1),tRise);
end

tRise = ts(tRise);
tFall = ts(tFall);

