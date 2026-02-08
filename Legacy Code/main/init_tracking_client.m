function sub = init_tracking_client()
    % Make sure Python is set up
    if ~strcmp(pyenv().Status, 'Loaded')
        % pyenv('Version', 'C:\Users\User\AppData\Local\Programs\Python\Python312\python.exe'); 
        pyenv('Version', 'C:\Users\amwLab\AppData\Local\Programs\Python\Python312\python.exe');
    end

    % Import trodesnetwork only once
    persistent imported
    if isempty(imported)
        py.importlib.import_module('trodesnetwork.socket');
        imported = true;
    end

    % Create the subscriber and return it
    sub = py.trodesnetwork.socket.SourceSubscriber('source.position');
end
