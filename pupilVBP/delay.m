function t = delay(dur)
tic; t = 0;
while toc < dur
    t = toc;
end

end