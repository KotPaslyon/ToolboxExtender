classdef ToolboxExtender < handle
    %A lot of powerful features for custom toolbox
    
    properties
        name % project name
        pname % name of project file
        type % type of project
        root % root dir
        remote % GitHub link
        vc % current installed version
        extv % Toolbox Extender version
    end
    
    properties (Hidden)
        config = 'ToolboxConfig.xml' % configuration file name
    end
    
    methods
        function obj = ToolboxExtender(root)
            % Init
            if nargin < 1
                obj.root = fileparts(mfilename('fullpath'));
            else
                obj.root = root;
            end
        end
        
        function set.root(obj, root)
            % Set root path
            obj.root = root;
            if ~obj.readconfig()
                obj.getpname();
                obj.gettype();
                obj.getname();
                obj.getremote();
            end
            obj.gvc();
        end
        
        function [vc, guid] = gvc(obj)
            % Get current installed version
            if obj.type == "toolbox"
                tbx = matlab.addons.toolbox.installedToolboxes;
                tbx = struct2table(tbx, 'AsArray', true);
                idx = strcmp(tbx.Name, obj.name);
                vc = tbx.Version(idx);
                guid = tbx.Guid(idx);
                if isscalar(vc)
                    vc = char(vc);
                elseif isempty(vc)
                    vc = '';
                end
            else
                tbx = matlab.apputil.getInstalledAppInfo;
                vc = '';
                guid = '';
            end
            obj.vc = vc;
        end
        
        function res = install(obj, fpath)
            % Install toolbox or app
            if nargin < 2
                fpath = obj.getbinpath();
            end
            if obj.type == "toolbox"
                res = matlab.addons.install(fpath);
            else
                res = matlab.apputil.install(fpath);
            end
            obj.gvc();
            obj.echo('has been installed');
        end
        
        function uninstall(obj)
            % Uninstall toolbox or app
            [~, guid] = obj.gvc();
            if isempty(guid)
                disp('Nothing to uninstall');
            else
                if obj.type == "toolbox"
                    matlab.addons.uninstall(guid);
                else
                    matlab.apputil.uninstall(guid);
                end
                disp('Uninstalled successfully');
                obj.gvc();
            end
        end
        
        function doc(obj, name)
            % Open page from documentation
            if nargin < 2
                name = 'GettingStarted';
            end
            if ~any(endsWith(name, {'.mlx' '.html'}))
                name = name + ".html";
            end
            docpath = fullfile(obj.root, 'doc', name);
            if endsWith(name, '.html')
                web(docpath);
            else
                open(docpath);
            end
        end
        
        function examples(obj)
            % cd to Examples dir
            expath = fullfile(obj.root, 'examples');
            cd(expath);
        end
        
    end
    
    
    methods (Hidden)
        
        function echo(obj, msg)
            % Display service message
            fprintf('%s %s\n', obj.name, msg);
        end
        
        function [nname, npath] = cloneclass(obj, classname)
            % Clone Toolbox Extander class to current Project folder
            if nargin < 2
                classname = "Extender";
            else
                classname = lower(char(classname));
                classname(1) = upper(classname(1));
            end
            nname = obj.getvalidname + string(classname);
            npath = nname + ".m";
            oname = "Toolbox" + classname;
            root = fileparts(mfilename('fullpath'));
            opath = fullfile(root, oname + ".m");
            copyfile(opath, npath);
            obj.txtrep(npath, oname, nname);
            obj.txtrep(npath, "obj.TE = ToolboxExtender", "obj.TE = " + obj.getvalidname + "Extender");
        end
        
        function name = getname(obj)
            % Get project name from project file
            name = '';
            ppath = fullfile(obj.root, obj.pname);
            if isfile(ppath)
                txt = obj.readtxt(ppath);
                name = char(extractBetween(txt, '<param.appname>', '</param.appname>'));
            end
            obj.name = name;
        end
        
        function pname = getpname(obj)
            % Get project file name
            fs = dir(fullfile(obj.root, '*.prj'));
            if ~isempty(fs)
                pname = fs(1).name;
                obj.pname = pname;
            else
                error('Project file was not found in a current folder');
            end
        end
        
        function type = gettype(obj)
            % Get project type (Toolbox/App)
            ppath = fullfile(obj.root, obj.pname);
            txt = obj.readtxt(ppath);
            if contains(txt, 'plugin.toolbox')
                type = 'toolbox';
            elseif contains(txt, 'plugin.apptool')
                type = 'app';
            else
                type = '';
            end
            obj.type = type;
        end
        
        function remote = getremote(obj)
            % Get remote (GitHub) address via Git
            [~, cmdout] = system('git remote -v');
            remote = extractBetween(cmdout, 'https://', '.git', 'Boundaries', 'inclusive');
            if ~isempty(remote)
                remote = remote(end);
            end
            remote = char(remote);
            obj.remote = remote;
        end
        
        function name = getvalidname(obj)
            % Get valid variable name
            name = char(obj.name);
            name = name(isstrprop(name, 'alpha'));
        end  
        
        function nfname = copyscript(obj, sname, newclass)
            % Copy script to Project folder
            root = fileparts(mfilename('fullpath'));
            spath = fullfile(root, 'scripts', sname + ".m");
            nfname = sname + ".m";
            copyfile(spath, nfname);
            if nargin > 2
                obj.txtrep(nfname, 'ToolboxDev', newclass);
            end
        end
        
        function txt = readtxt(~, fpath)
            % Read text from file
            f = fopen(fpath, 'r', 'n', 'windows-1251');
            txt = fread(f, '*char')';
            fclose(f);
        end
        
        function writetxt(~, txt, fpath)
            % Wtite text to file
            fid = fopen(fpath, 'w', 'n', 'windows-1251');
            fwrite(fid, unicode2native(txt, 'windows-1251'));
            fclose(fid);
        end
        
        function txt = txtrep(obj, fpath, old, new)
            % Replace in txt file
            txt = obj.readtxt(fpath);
            txt = replace(txt, old, new);
            obj.writetxt(txt, fpath);
        end
        
        function bpath = getbinpath(obj)
            % Get generated binary file path
            [~, name] = fileparts(obj.pname);
            if obj.type == "toolbox"
                ext = ".mltbx";
            else
                ext = ".mlappinstall";
            end
            bpath = fullfile(obj.root, name + ext);
        end
        
        function ok = readconfig(obj)
            % Read config from xml file
            confpath = fullfile(obj.root, obj.config);
            ok = isfile(confpath);
            if ok
                xml = xmlread(confpath);
                conf = obj.getxmlitem(xml, 'config', 0);
                obj.name = obj.getxmlitem(conf, 'name');
                obj.pname = obj.getxmlitem(conf, 'pname');
                obj.type = obj.getxmlitem(conf, 'type');
                obj.remote = erase(obj.getxmlitem(conf, 'remote'), '.git');
                obj.extv = obj.getxmlitem(conf, 'extv');
            end
        end
        
        function [confname, confpath] = writeconfig(obj)
            % Write config to xml file
            docNode = com.mathworks.xml.XMLUtils.createDocument('config');
            docNode.appendChild(docNode.createComment('ToolboxUpdater configuration file'));
            obj.addxmlitem(docNode, 'name', obj.name);
            obj.addxmlitem(docNode, 'pname', obj.pname);
            obj.addxmlitem(docNode, 'type', obj.type);
            obj.addxmlitem(docNode, 'remote', obj.remote);
            obj.addxmlitem(docNode, 'extv', obj.extv);
            confpath = fullfile(obj.root, obj.config);
            confname = obj.config;
            xmlwrite(confpath, docNode);
        end
        
        function i = getxmlitem(~, xml, name, getData)
            % Get item from XML
            if nargin < 4
                getData = true;
            end
            i = xml.getElementsByTagName(name);
            i = i.item(0);
            if getData
                i = i.getFirstChild;
                if ~isempty(i)
                    i = i.getData;
                end
                i = char(i);
            end
        end
        
        function addxmlitem(~, node, name, value)
            % Add item to XML
            doc = node.getDocumentElement;
            el = node.createElement(name);
            el.appendChild(node.createTextNode(value));
            doc.appendChild(el);
        end
        
    end
end