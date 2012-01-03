"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/table': '0.1',
                \        '@aurum/cmdutils': '0.0',
                \         '@aurum/bufvars': '0.0',
                \            '@aurum/edit': '1.0',
                \                  '@/fwc': '0.3',
                \            '@aurum/repo': '1.3',
                \             '@/commands': '0.0',
                \            '@/functions': '0.0',
                \              '@/options': '0.0',}, 0)
    call FraworLoad('@/commands')
    call FraworLoad('@/functions')
    let s:logcomp=[]
    let s:logfunc={}
    call s:_f.command.add('AuLog', s:logfunc, {'nargs': '*',
                \                           'complete': s:logcomp})
    finish
elseif s:_pluginloaded
    finish
endif
let s:F.glog={}
let s:F.graph={}
let s:F.temp={}
let s:_options={
            \'ignorefiles': {'default': [],
            \                'checker': 'list in [patch renames copies files]'},
            \'closewindow': {'default': 1, 'filter': 'bool'},
        \}
let s:_messages={
            \'2multl': 'Two multiline statements on one line',
            \'argmis': 'Missing argument #%u for keyword %s',
        \}
"▶1 graph
"▶2 graph.update_state :: graph, gstate → + graph
function s:F.graph.update_state(s)
    let self.prev_state=self.state
    let self.state=a:s
endfunction
"▶2 graph.ensure_capacity :: graph, num_columns → + graph
function s:F.graph.ensure_capacity(num_columns)
    let mdiff=(a:num_columns*2)-len(self.mapping)
    if mdiff>0
        let plist=repeat([-1], mdiff)
        let self.mapping+=plist
        let self.new_mapping+=plist
    endif
endfunction
"▶2 graph.insert_into_new_columns :: graph, cs, mapindex → mapindex + graph
function s:F.graph.insert_into_new_columns(cs, mapindex)
    let i=0
    for hex in self.new_columns
        if hex is# a:cs.hex
            let self.mapping[a:mapindex]=i
            return a:mapindex+2
        endif
        let i+=1
    endfor
    let self.mapping[a:mapindex]=len(self.new_columns)
    call add(self.new_columns, a:cs.hex)
    return a:mapindex+2
endfunction
"▶2 graph.update_columns :: graph → + graph
function s:F.graph.update_columns()
    let self.columns=self.new_columns
    let self.new_columns=[]
    let max_new_columns=len(self.columns)+self.num_parents
    call self.ensure_capacity(max_new_columns)
    let self.mapping_size=2*max_new_columns
    if !empty(self.mapping)
        call remove(self.mapping, 0, self.mapping_size-1)
    endif
    call extend(self.mapping, repeat([-1], self.mapping_size), 0)
    let seen=0
    let midx=0
    let is_cs_in_columns=1
    let num_columns=len(self.columns)
    for i in range(num_columns+1)
        if i==num_columns
            if seen
                break
            endif
            let is_cs_in_columns=0
            let ccshex=self.cs.hex
        else
            let ccshex=self.columns[i]
        endif
        if ccshex is# self.cs.hex
            let oldmidx=midx
            let seen=1
            let self.commit_index=i
            for parent in self.interesting_parents
                let midx=self.insert_into_new_columns(
                            \                self.repo.changesets[parent], midx)
            endfor
            if midx==oldmidx
                let midx+=2
            endif
        else
            let midx=self.insert_into_new_columns(self.repo.changesets[ccshex],
                        \                         midx)
        endif
    endfor
    while self.mapping_size>1 && self.mapping[self.mapping_size-1]==-1
        let self.mapping_size-=1
    endwhile
    let self.width=(len(self.columns)+self.num_parents+(self.num_parents<1)
                \  -(is_cs_in_columns))*2
endfunction
"▶2 graph.update :: graph, cs → + graph
function s:F.graph.update(cs)
    let self.cs=a:cs
    let self.interesting_parents=filter(copy(a:cs.parents),
                \                       'has_key(self.addchangesets, v:val)')
    let self.num_parents=len(self.interesting_parents)
    let self.prev_commit_index=self.commit_index
    call self.update_columns()
    let self.expansion_row=0
    if self.state isnot# 'padding'
        let self.state='skip'
    elseif self.num_parents>2 &&
                \self.commit_index<(len(self.columns)-1)
        let self.state='precommit'
    else
        let self.state='commit'
    endif
endfunction
"▶2 graph.is_mapping_correct :: graph → Bool
function s:F.graph.is_mapping_correct()
    return empty(filter(self.mapping[:(self.mapping_size-1)],
                \       '!(v:val==-1 || v:val==v:key/2)'))
endfunction
"▶2 graph.pad_horizontally :: graph, chars_written → String
" XXX Replace somehow?
function s:F.graph.pad_horizontally(chars_written)
    if a:chars_written>=self.width
        return ''
    endif
    return repeat(' ', self.width-a:chars_written)
endfunction
"▶2 graph.output_padding_line :: graph → String
function s:F.graph.output_padding_line()
    let lnc=len(self.new_columns)
    return repeat('| ', lnc).self.pad_horizontally(lnc*2)
endfunction
"▶2 graph.output_skip_line :: graph → String
function s:F.graph.output_skip_line()
    call self.update_state(((self.num_parents>2 &&
                \            self.commit_index<(len(self.columns)-1))?
                \               ('precommit'):
                \               ('commit')))
    return '...'.self.pad_horizontally(3)
endfunction
"▶2 graph.output_pre_commit_line :: graph → String
function s:F.graph.output_pre_commit_line()
    let num_expansion_rows=(self.num_parents-2)*2
    let seen=0
    let r=''
    let i=-1
    for hex in self.columns
        let i+=1
        if hex is# self.cs.hex
            let seen=1
            let r.='|'.repeat(' ', self.expansion_row)
        elseif seen && self.expansion_row==0
            let r.='|\'[self.prev_state is# 'postmerge' &&
                        \self.prev_commit_index<i]
        elseif seen && self.expansion_row>0
            let r.='\'
        else
            let r.='|'
        endif
        let r.=' '
    endfor
    let r.=self.pad_horizontally(len(r))
    let self.expansion_row+=1
    if self.expansion_row>num_expansion_rows
        call self.update_state('commit')
    endif
    return r
endfunction
"▶2 graph.output_commit_char :: graph → String
function s:F.graph.output_commit_char()
    return '@o'[index(self.workcss, self.cs.hex)==-1]
endfunction
"▶2 graph.draw_octopus_merge :: graph → String
function s:F.graph.draw_octopus_merge()
    let r=''
    for i in range(((self.num_parents-2)*2)-1)
        let r.='-'
    endfor
    let r.='.'
    return r
endfunction
"▶2 graph.output_commit_line :: graph → String
function s:F.graph.output_commit_line()
    let seen=0
    let r=''
    let lcolumns=len(self.columns)
    for i in range(lcolumns+1)
        if i==lcolumns
            if seen
                break
            endif
            let ccshex=self.cs.hex
        else
            let ccshex=self.columns[i]
        endif
        if ccshex is# self.cs.hex
            let seen=1
            let r.=self.output_commit_char()
            if self.num_parents>2
                let r.=self.draw_octopus_merge()
            endif
        elseif seen && self.num_parents>2
            let r.='\'
        elseif seen && self.num_parents==2
            let r.='|\'[self.prev_state is# 'postmerge' &&
                        \self.prev_commit_index<i]
        else
            let r.='|'
        endif
        let r.=' '
    endfor
    let r.=self.pad_horizontally(len(r))
    call self.update_state(((self.num_parents>1)?
                \             ('postmerge'):
                \          ((self.is_mapping_correct())?
                \             ('padding')
                \          :
                \             ('collapsing'))))
    return r
endfunction
"▶2 graph.output_post_merge_line :: graph → String
function s:F.graph.output_post_merge_line()
    let seen=0
    let r=''
    let lcolumns=len(self.columns)
    for i in range(lcolumns+1)
        if i==lcolumns
            if seen
                break
            endif
            let ccshex=self.cs.hex
        else
            let ccshex=self.columns[i]
        endif
        if ccshex is# self.cs.hex
            let seen=1
            let r.='|'.repeat('\ ', self.num_parents-1)
        else
            let r.='|\'[seen].' '
        endif
    endfor
    let r.=self.pad_horizontally(len(r))
    call self.update_state(((self.is_mapping_correct())?
                \               ('padding'):
                \               ('collapsing')))
    return r
endfunction
"▶2 graph.output_collapsing_line :: graph → String
function s:F.graph.output_collapsing_line()
    let used_horizontal=0
    let horizontal_edge=-1
    let horizontal_edge_target=-1
    let self.new_mapping=repeat([-1], self.mapping_size)
    for [i, target] in map(self.mapping[:(self.mapping_size-1)],
                \          '[v:key, v:val]')
        if target==-1
            continue
        elseif i==target*2
            let self.new_mapping[i]=target
        elseif self.new_mapping[i-1]==-1
            let self.new_mapping[i-1]=target
            if horizontal_edge==-1
                let horizontal_edge=i
                let horizontal_edge_target=target
                let j=(target*2)+3
                while j<i-2
                    let self.new_mapping[j]=target
                    let j+=2
                endwhile
            endif
        elseif self.new_mapping[i-1]==target
        else
            let self.new_mapping[i-2]=target
            if horizontal_edge==-1
                let horizontal_edge=1
            endif
        endif
    endfor
    if self.mapping[self.mapping_size-1]==-1
        let self.mapping_size-=1
    endif
    let r=''
    for [i, target] in map(self.new_mapping[:(self.mapping_size-1)],
                \          '[v:key, v:val]')
        if target==-1
            let r.=' '
        elseif target*2==i
            let r.='|'
        elseif target==horizontal_edge_target && i!=horizontal_edge-1
            if i!=(target*2)+3
                let self.new_mapping[i]=-1
            endif
            let used_horizontal=1
            let r.='_'
        else
            if used_horizontal && i<horizontal_edge
                let self.new_mapping[i]=-1
            endif
            let r.='/'
        endif
    endfor
    let r.=self.pad_horizontally(len(r))
    let [self.mapping, self.new_mapping]=
                \[self.new_mapping, self.mapping]
    if self.is_mapping_correct()
        call self.update_state('padding')
    endif
    return r
endfunction
"▶2 graph.next_line :: graph → String
let s:gstatesfmap={
            \'padding':    s:F.graph.output_padding_line,
            \'skip':       s:F.graph.output_skip_line,
            \'precommit':  s:F.graph.output_pre_commit_line,
            \'commit':     s:F.graph.output_commit_line,
            \'postmerge':  s:F.graph.output_post_merge_line,
            \'collapsing': s:F.graph.output_collapsing_line,
        \}
function s:F.graph.next_line()
    return call(s:gstatesfmap[self.state], [], self)
endfunction
"▶2 graph.padding_line :: graph → String
function s:F.graph.padding_line()
    if self.state isnot# 'commit'
        return self.next_line()
    endif
    if self.num_parents<3
        let r.=repeat('| ', len(self.columns))
    else
        let r.=join(map(copy(self.columns),
                    \   '"|".((v:val is# "'.self.cs.hex.'")?'.
                    \           'repeat(" ", (self.num_parents-2)*2):'.
                    \           '" ")'), '')
    endif
    let r.=self.pad_horizontally(len(r))
    let self.prev_state='padding'
    return r
endfunction
"▶2 graph.show_commit :: graph → [String]
function s:F.graph.show_commit()
    let r=[]
    while 1
        try
            if self.state is# 'commit'
                break
            endif
        finally
            " XXX We need at least one iteration. :finally makes sure it will be 
            " done
            let r+=[self.next_line()]
        endtry
    endwhile
    return r
endfunction
"▶2 graph.show_remainder :: graph → [String]
function s:F.graph.show_remainder()
    let r=[]
    while self.state isnot# 'padding'
        let r+=[self.next_line()]
    endwhile
    return r
endfunction
"▶1 glog
"▶2 glog.utfedges
function s:F.glog.utfedges(seen, hex, parents)
    let nodeidx=index(a:seen, a:hex)
    if nodeidx==-1
        let nodeidx=len(a:seen)
        call add(a:seen, a:hex)
    endif
    let knownparents=[]
    let newparents=[]
    for parenthex in a:parents
        call add(((index(a:seen, parenthex)==-1)?
                    \   (newparents):
                    \   (knownparents)),
                    \parenthex)
    endfor
    let ncols=len(a:seen)
    call remove(a:seen, nodeidx)
    call extend(a:seen, newparents, nodeidx)
    let edges=map(knownparents, '['.nodeidx.', index(a:seen, v:val)]')
    if !empty(newparents)
        call add(edges, [nodeidx, nodeidx])
        if len(newparents)>1
            call add(edges, [nodeidx, nodeidx+1])
        endif
    endif
    let nmorecols=len(a:seen)-ncols
    return [nodeidx, edges, ncols, nmorecols]
endfunction
"▶2 glog.fix_long_right_edges
function s:F.glog.fix_long_right_edges(edges)
    call map(a:edges, '((v:val[1]>v:val[0])?([v:val[0], v:val[1]+1]):(v:val))')
endfunction
"▶2 glog.get_nodeline_edges_tail
function s:F.glog.get_nodeline_edges_tail(node_index, p_node_index, n_columns,
            \                             n_columns_diff, p_diff, fix_tail)
    if a:fix_tail && a:n_columns_diff==a:p_diff && a:n_columns_diff!=0
        if a:n_columns_diff==-1
            let start=max([a:node_index+1, a:p_node_index])
            return repeat(['|', ' '], (start-a:node_index-1))+
                        \repeat(['/', ' '], (a:n_columns-start))
        else
            return repeat(['\', ' '], (a:n_columns-a:node_index-1))
        endif
    else
        return repeat(['|', ' '], (a:n_columns-a:node_index-1))
    endif
endfunction
"▶2 glog.draw_edges
function s:F.glog.draw_edges(edges, nodeline, interline)
    for [start, end] in a:edges
        if start==end+1
            let a:interline[2*end   + 1]='/'
        elseif start==end-1
            let a:interline[2*start + 1]='\'
        elseif start==end
            let a:interline[2*start    ]='|'
        else
            let a:nodeline[2*end]='+'
            if start>end
                let [start, end]=[end, start]
            endif
            for i in range(2*start+1, 2*end-1)
                if a:nodeline[i] isnot# '+'
                    let a:nodeline[i]='-'
                endif
            endfor
        endif
    endfor
endfunction
"▶2 glog.get_padding_line
function s:F.glog.get_padding_line(ni, n_columns, edges)
    let c=' '
    if index(a:edges, [a:ni, a:ni-1])!=-1 || index(a:edges, [a:ni, a:ni])!=-1
        let c='|'
    endif
    return repeat(['|', ' '], a:ni)+
                \[c, ' ']+
                \repeat(['|', " "], (a:n_columns-a:ni-1))
endfunction
"▶2 glog.addlines
function s:F.glog.addlines(special, lnum)
    let mapexpr='[v:val[0]+'.a:lnum.']+v:val[1:]'
    call map(a:special, 'v:key[-2:] is? "_r"?'.
                \             'map(v:val, '.string(mapexpr).'):'.
                \             mapexpr)
    return a:special
endfunction
"▶2 glog.addcols
function s:F.glog.addcols(special, cnum)
    let mapexpr='[v:val[0], v:val[1]+'.a:cnum.']+v:val[2:]'
    call map(a:special, 'v:key[-2:] is? "_r"?'.
                \             'map(v:val, '.string(mapexpr).'):'.
                \             mapexpr)
    return a:special
endfunction
"▶2 glog.utf
function s:F.glog.utf(state, type, char, text, coldata)
    let [idx, edges, ncols, coldiff]=a:coldata
    let add_padding_line=0
    let lnum = (has_key(a:text, 'text') ? len(a:text.text) : 0)
    if coldiff==-1
        call s:F.glog.fix_long_right_edges(edges)
        if lnum>2
            let add_padding_line=!empty(map(filter(copy(edges),
                        \                          '(v:val[0]+1)<v:val[1]'),
                        \                   'v:val[0]'))
        endif
    endif
    let fix_nodeline_tail = (lnum<=2 && add_padding_line)
    let shift_interline=repeat(['|', ' '], idx)
    let nodeline=copy(shift_interline)+
                \[a:char, ' ']+
                \s:F.glog.get_nodeline_edges_tail(idx,     a:state[1], ncols,
                \                                 coldiff, a:state[0],
                \                                 fix_nodeline_tail)
    if coldiff==-1
        let n_spaces=1
        let edge_ch='/'
    elseif coldiff==0
        let n_spaces=2
        let edge_ch='|'
    else
        let n_spaces=3
        let edge_ch='\'
    endif
    let shift_interline+=repeat([' '], n_spaces)+
                \        repeat([edge_ch, ' '], (ncols-idx-1))
    call s:F.glog.draw_edges(edges, nodeline, shift_interline)
    let lines=[nodeline]
    if add_padding_line
        call add(lines, s:F.glog.get_padding_line(idx, ncols, edges))
    endif
    if has_key(a:text, 'skip')
        let joined_sil=join(shift_interline, '')
        let joined_nl=substitute(join(nodeline, ''), '\V'.a:char, '|', '')
        let a:text.text=[]
        if joined_nl!~#'\v^[o| ]+$'
            let a:text.text+=[substitute(joined_nl,'\v\-@<=\||\|\-@=','+','')]
        endif
        if joined_sil!~#'\v^[| ]+$' && joined_sil isnot# joined_nl
            let a:text.text+=[joined_sil]
        endif
        return a:text
    else
        call add(lines, shift_interline)
    endif
    let ltdiff=lnum-len(lines)
    if ltdiff>0
        let extra_interline=repeat(['|', ' '], ncols+coldiff)
        call extend(lines, repeat([extra_interline], ltdiff))
    else
        call extend(a:text.text, repeat([''], -ltdiff))
    endif
    let indentation_level=2*max([ncols, ncols+coldiff])
    let a:state[0]=coldiff
    let a:state[1]=idx
    call map(lines, 'printf("%-*s ", indentation_level, join(v:val, ""))')
    let curspecial=a:text.special
    let shiftlen=len(lines[0])
    call s:F.glog.addcols(a:text.special, shiftlen)
    let a:text.block_r=[[0, shiftlen],
                \       [len(a:text.text)-1,
                \        max(map(copy(lines), 'len(v:val)'))]]
    let curspecial.bullet=[0, stridx(lines[0], a:char), a:char]
    call map(a:text.text, 'lines[v:key].v:val')
    return a:text
endfunction
"▶2 glog.generate
function s:F.glog.generate(css, showparents, opts)
    let seen=[]
    let state=[0, 0]
    let r=      {'text': [],
                \'specials': {},
                \'rectangles': [],
                \'csstarts': {},}
    for cs in a:css
        let char=((index(a:showparents, cs.hex)==-1)?('o'):('@'))
        if has_key(a:opts.skipchangesets, cs.hex)
            let text={'skip': 1}
            let skip=1
        else
            let text=a:opts.templatefunc(cs, a:opts)
            let skip=0
        endif
        call s:F.glog.utf(state, 'C', char, text,
                    \     s:F.glog.utfedges(seen, cs.hex, cs.parents))
        if !has_key(text, 'text') || empty(text.text)
            continue
        endif
        if !skip
            let text.block_r[0][0]+=len(r.text)
            let text.block_r[1][0]+=len(r.text)
            let r.specials[cs.hex]=text.special
            let r.rectangles+=[text.block_r+[cs.hex]]
            let r.csstarts[cs.hex]=text.block_r[0][0]
        endif
        let r.text+=text.text
    endfor
    return r
endfunction
"▶2 glog.graph_init :: repo, [cs] → graph
let s:defgraph={
            \'cs':                0,
            \'num_parents':       0,
            \'expansion_row':     0,
            \'state':             'padding',
            \'prev_state':        'padding',
            \'commit_index':      0,
            \'prev_commit_index': 0,
            \'columns':           [],
            \'new_columns':       [],
            \'mapping':           [],
            \'new_mapping':       [],
            \'mapping_size':      0,
            \'addchangesets':     {},
        \}
function s:F.glog.graph_init(css, showparents, opts)
    let graph=deepcopy(s:defgraph)
    let graph.repo=a:opts.repo
    let graph.workcss=a:showparents
    call map(copy(a:css),
                \'((has_key(a:opts.skipchangesets, v:val.hex))?(0):'.
                \   '(extend(graph.addchangesets, {v:val.hex : v:val})))')
    call extend(graph, s:F.graph)
    return graph
endfunction
"▶2 glog.show_log :: graph, cs, Text → Text
function s:F.glog.show_log(graph, cs, text)
    let lines=((a:graph.cs is 0)?([]):(a:graph.show_remainder()))
    call a:graph.update(a:cs)
    let lines+=a:graph.show_commit()
    let collen=len(lines[-1])
    let a:text.block_r[0][1]+=collen
    let a:text.block_r[1][1]+=collen
    let lines[-1]=lines[-1][:-2].' '.get(a:text.text, 0, '')
    let cchar=a:graph.output_commit_char()
    let bidx=stridx(lines[-1], cchar)
    if bidx!=-1
        let a:text.special.bullet=[0, bidx, cchar]
    endif
    for line in a:text.text[1:]
        let lines+=[a:graph.next_line()[:-2].' '.line]
    endfor
    let a:text.text=lines
    return a:text
endfunction
"▶2 glog.log_show_all :: [cs], showparents, opts → Log
function s:F.glog.log_show_all(css, showparents, opts)
    let graph=s:F.glog.graph_init(a:css, a:showparents, a:opts)
    let show_header=1
    let r={'text': [], 'specials': {}, 'rectangles': [], 'csstarts': {}}
    for cs in filter(copy(a:css), 'has_key(graph.addchangesets, v:val.hex)')
        let text=a:opts.templatefunc(cs, a:opts)
        let text.block_r=[[0, 0],
                    \     [len(text.text)-1,
                    \      max(map(copy(text.text), 'len(v:val)'))]]
        let text=s:F.glog.show_log(graph, cs, text)
        let r.text+=text.text
        let text.block_r[0][0]+=len(r.text)
        let text.block_r[1][0]+=len(r.text)
        let r.specials[cs.hex]=text.special
        let r.rectangles+=[text.block_r+[cs.hex]]
        let r.csstarts[cs.hex]=text.block_r[0][0]
    endfor
    return r
endfunction
"▶2 s:DateCmp :: cs, cs → -1|0|1
function s:DateCmp(a, b)
    let a=a:a.time
    let b=a:b.time
    return ((a==b)?(0):((a>b)?(-1):(1)))
endfunction
let s:_functions+=['s:DateCmp']
"▶2 glog.sort_in_topological_order :: [cs] → [cs]
function s:F.glog.sort_in_topological_order(repo, css)
    call map(copy(a:css), 'extend(v:val, {"indegree": 1})')
    for parents in map(copy(a:css), 'v:val.parents')
        for parent in filter(map(filter(copy(parents),
                    \                   'has_key(a:repo.changesets, v:val)'),
                    \            'a:repo.changesets[v:val]'),
                    \        'get(v:val, "indegree", 0)')
            let parent.indegree+=1
        endfor
    endfor
    let work=[]
    call map(copy(a:css), 'v:val.indegree==1 && add(work, v:val) is 0')
    call sort(work, 's:DateCmp')
    let r=[]
    while !empty(work)
        let cs=remove(work, 0)
        for parent in filter(map(filter(copy(cs.parents),
                    \                   'has_key(a:repo.changesets, v:val)'),
                    \            'a:repo.changesets[v:val]'),
                    \        'get(v:val, "indegree", 0)')
            let parent.indegree-=1
            if parent.indegree==1
                let j=0
                let lwork=len(work)
                while j<lwork && work[j].time<parent.time
                    let j+=1
                endwhile
                call insert(work, parent, j)
            endif
        endfor
        let cs.indegree=0
        call add(r, cs)
    endwhile
    call map(copy(a:css), 'remove(v:val, "indegree")')
    return r
endfunction
"▶2 glog.graphlog
function s:F.glog.graphlog(repo, opts, css)
    if get(a:repo, 'requires_sort', 1)
        let css=s:F.glog.sort_in_topological_order(a:repo, a:css)
    else
        let css=reverse(copy(a:css))
    endif
    let d={}
    if get(a:repo, 'has_octopus_merges', 1)
        let d.func=s:F.glog.log_show_all
    else
        let d.func=s:F.glog.generate
    endif
    return d.func(css, [a:repo.functions.getworkhex(a:repo)], a:opts)
endfunction
"▶1 temp
"▶2 s:templates
let s:templates={
            \'default': "Changeset $rev#suf:\:#$hex$branch#hide,pref: (branch ,suf:)#\n".
            \           "Commited $time by $user\n".
            \           "Tags: $tags\n".
            \           "Bookmarks: $bookmarks\n".
            \           "Files: $changes\n".
            \           "Renamed $renames\n".
            \           "Copied $copies\n".
            \           "$hide#@# $description\n".
            \           "$hide#$#$stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'hgdef':   "changeset:   $rev#suf:\:#$hex\n".
            \           "branch:      $branch\n".
            \           "tags:        $tags\n".
            \           "bookmarks:   $bookmarks\n".
            \           "user:        $user\n".
            \           "date:        $time#%a %b %d %H:%M:%S %Y#\n".
            \           "files:       $changes# #\n".
            \           "summary:     $summary\n".
            \           "$hide#$#$stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'hgdescr': "changeset:   $rev#suf:\:#$hex\n".
            \           "branch:      $branch\n".
            \           "tags:        $tags\n".
            \           "bookmarks:   $bookmarks\n".
            \           "user:        $user\n".
            \           "date:        $time#%a %b %d %H:%M:%S %Y#\n".
            \           "files:       $changes# #\n".
            \           "description:\n".
            \           "$description\n".
            \           "$hide#$#$stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'compact': "$rev$tags#pref:[,suf:]#   $hex $time#%Y-%m-%d %H:%M# $user\n".
            \           "  $summary\n".
            \           "$hide#$# $stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'cdescr':  "$rev$tags#pref:[,suf:]#   $hex $time#%Y-%m-%d %H:%M# $user\n".
            \           "  $description\n".
            \           "$hide#$# $stat\n".
            \           "$hide#:#$patch\n".
            \           "$empty",
            \'git':     "commit $hex\n".
            \           "Author: $user\n".
            \           "Date:   $time#%a %b %d %T %Y#\n".
            \           "$empty\n".
            \           "    $description\n".
            \           "$empty\n".
            \           "$hide#$# $stat\n".
            \           "$hide#:#$patch",
            \'gitoneline': "$hex $summary\n".
            \              "$hide#$# $stat\n".
            \              "$hide#:#$patch",
        \}
"▶2 s:kwexpr
" TODO Add bisection status
let s:kwexpr={}
let s:kwexpr.hide        = [0, '@0@', 0]
let s:kwexpr.empty       = [0, '@@@']
let s:kwexpr.hex         = [0, '@@@']
let s:kwexpr.branch      = [0, '@@@', 'keep']
let s:kwexpr.user        = [0, '@@@']
let s:kwexpr.rev         = [0, '@@@', 'ignore']
let s:kwexpr.time        = [0, 'strftime(@0@, @@@)', '%d %b %Y %H:%M']
let s:kwexpr.parents     = [0, 'join(@@@)']
let s:kwexpr.children    = [0, 'join(@@@)']
let s:kwexpr.tags        = [0, 'join(@@@, @0@)', ', ']
let s:kwexpr.bookmarks   = [0, 'join(@@@, @0@)', ', ']
let s:kwexpr.summary     = [0, '@@@']
" TODO Add tab expansion
let s:kwexpr.description = [1, 'split(@@@, "\n")']
let s:kwexpr.patch       = [1, '@@@']
let s:kwexpr.stat        = [2, 's:F.temp.stat(@@@, a:cs.files, @<@)']
let s:kwexpr.files       = [2, 's:F.temp.multlfmt(@@@, a:cs.files, '.
            \                                    '@<@, @0@, '.
            \                                    '"file")', ', ']
let s:kwexpr.changes     = [2, 's:F.temp.multlfmt(@@@, a:cs.changes, '.
            \                                    '@<@, @0@, '.
            \                                    '"file")', ', ']
let s:kwexpr.renames     = [2, 's:F.temp.renames(@@@, a:cs.files, '.
            \                                   '@<@, @0@)', ' to ']
let s:kwexpr.copies      = [2, 's:F.temp.renames(@@@, a:cs.files, '.
            \                                   '@<@, @0@)', ' to ']
let s:kwmarg={}
let s:kwmarg.summary='matchstr(a:cs.description, "\\\\v^[^\\n]*")'
let s:kwmarg.stat='a:opts.repo.functions.getstats(a:opts.repo, diff, a:opts)'
let s:kwmarg.patch='diff'
let s:kwmarg.empty=''''''
let s:kwpempt=['parents', 'children', 'tags', 'bookmarks']
let s:kwreg={
            \'rev' : '\d\+',
            \'parents': '\v\x{12,}( \x{12,})?',
            \'children': '\v\x{12,}( \x{12,})*',
        \}
"▶2 temp.stat :: stats, idxlist, linebeg → ([String], sp)
function s:F.temp.stat(stats, idxlist, linebeg)
    let sitems=map(sort(keys(a:stats.files)),
                \  '[v:val, '.
                \  'a:stats.files[v:val].insertions, '.
                \  'a:stats.files[v:val].deletions, '.
                \  's:_r.strdisplaywidth(v:val), '.
                \  'index(a:idxlist, v:val)]')
    let maxflen=max(map(copy(sitems), 'v:val[3]'))
    let maxilen=len(a:stats.insertions)
    let maxdlen=len(a:stats.deletions)
    let rt=[]
    let special={}
    for [file, ins, del, flen, fi] in sitems
        if fi!=-1
            let special['file00'.fi.'_l']=[len(rt), 0]
        endif
        let rt+=['  '.file.repeat(' ', maxflen-flen+1).'|'.
                    \ repeat(' ', maxilen-len(ins)+1).ins.
                    \ repeat(' ', maxdlen-len(del)+1).del]
    endfor
    let special.stat_R=[[0, 0], [len(rt), 0]]
    let rt+=[printf('%u files changed, %u insertions, %u deletions',
                \   len(keys(a:stats.files)),
                \   a:stats.insertions, a:stats.deletions)]
    call map(rt, 'a:linebeg.v:val')
    return [rt, special]
endfunction
"▶2 temp.renames :: renames, idxlist, linebeg, rensep → ([String], sp)
function s:F.temp.renames(renames, idxlist, linebeg, rensep)
    let rt=[]
    let special={}
    let rsl=len(a:rensep)
    for [cur, old] in items(filter(copy(a:renames), 'type(v:val)=='.type('')))
        let cl=len(rt)
        let fl=len(cur)
        let ol=len(old)
        let rt+=[a:linebeg.old.a:rensep.cur]
        let ll=len(rt[-1])
        let fi=index(a:idxlist, cur)
        let special['file0'.fi.'_r']=[[cl, ll-fl], [cl, ll-1]]
        let special['oldname'.fi.'_r']=[[cl, ll-fl-rsl-ol], [cl, ll-fl-rsl]]
        let special['rename'.fi.'_l']=[cl, 0]
    endfor
    return [rt, special]
endfunction
"▶2 temp.multlfmt :: list, idxlist, linebeg, itemsep, itemname → ([String], sp)
function s:F.temp.multlfmt(list, idxlist, linebeg, itemsep, itemname)
    let rt=[a:linebeg]
    let special={}
    let winwidth=winwidth(0)-10
    let linewidth=s:_r.strdisplaywidth(a:linebeg)
    let curfilenum=0
    let ii=-1
    let seplen=len(a:itemsep)
    for item in a:list
        let iwidth=s:_r.strdisplaywidth(item, linewidth)
        if curfilenum && iwidth+linewidth>winwidth
            let rt+=[a:linebeg.item.a:itemsep]
            let linewidth=s:_r.strdisplaywidth(rt[-1])
            let curfilenum=0
        else
            let rt[-1].=item.a:itemsep
            let linewidth+=iwidth
        endif
        let cl=len(rt)-1
        let ilen=len(item)
        let linelen=len(rt[-1])
        if a:list is a:idxlist
            let ii+=1
        else
            let ii=index(a:idxlist, item)
        endif
        let special[a:itemname.ii.'_r']=[[cl, linelen-ilen-seplen],
                    \                    [cl, linelen-seplen]]
        let curfilenum+=1
    endfor
    call map(rt, 'v:val[:-'.(seplen+1).']')
    return [rt, special]
endfunction
"▶2 temp.parsearg :: String → dict
function s:F.temp.parsearg(str)
    let s=a:str
    let r={}
    let i=0
    while !empty(s)
        let key=matchstr(s, '\v^%(expr|synreg|flbeg|pref|suf):')[:-2]
        if empty(key)
            let arg=matchstr(s, '\v(\\.|[^,])*')
            let s=s[len(arg)+1:]
            let r[i]=substitute(arg, '\v\\([\\:#,])', '\1', 'g')
            let i+=1
            continue
        endif
        let s=s[len(key)+1:]
        let arg=matchstr(s, '\v(\\.|[^,])*')
        let s=s[len(arg)+1:]
        let r[key]=substitute(arg, '\v\\([\\:#,])', '\1', 'g')
    endwhile
    return r
endfunction
"▶2 temp.parse :: String → template
let s:parsecache={}
function s:F.temp.parse(str)
    if has_key(s:parsecache, a:str)
        return s:parsecache[a:str]
    endif
    let s=a:str
    let r=[[[]]]
    let lr=r[-1]
    let t=lr[0]
    while !empty(s)
        let lit=matchstr(s, "\\v^[^$\n]*")
        let t+=[lit]
        let s=s[len(lit):]
        let c=s[0]
        let s=s[1:]
        if empty(s)
            break
        endif
        if c is# "\n"
            let r+=[[[]]]
            let lr=r[-1]
            let t=lr[0]
            continue
        endif
        let kw=matchstr(s, '\v^\w+')
        let s=s[len(kw):]
        if !has_key(s:kwexpr, kw)
            if len(t)>1
                let t[-2].=remove(t, -1)
            endif
            continue
        endif
        let astr=matchstr(s, '\v^\#(\\.|[^#])+\#')
        let arg=s:F.temp.parsearg(astr[1:-2])
        if s:kwexpr[kw][0] && !empty(filter(lr[1:], 's:kwexpr[v:val[0]][0]'))
            call s:_f.throw('2multl')
        endif
        let s=s[len(astr):]
        let lr+=[[kw, arg]]
    endwhile
    let s:parsecache[a:str]=r
    return r
endfunction
"▶2 temp.skip
function s:F.temp.skip(meta, opts)
    for kw in map(copy(a:meta), 'v:val[0]')
        if (!get(a:opts, 'showfiles', 0) &&
                    \   (kw is# 'files' || kw is# 'changes')) ||
                    \(!get(a:opts, 'showrenames', 0) && kw is# 'renames') ||
                    \(!get(a:opts, 'showcopies',  0) && kw is# 'copies')  ||
                    \(!get(a:opts, 'patch',       0) && kw is# 'patch')   ||
                    \(!get(a:opts, 'stat',        0) && kw is# 'stat')
            return 1
        endif
    endfor
    return 0
endfunction
"▶2 temp.compile :: template, opts → Fref
let s:compilecache={}
function s:F.temp.compile(template, opts)
    "▶3 Cache
    let cid=''
    for o in ['patch', 'stat', 'showfiles', 'showrenames', 'showcopies']
        let cid.=get(a:opts, o, 0)
    endfor
    let cid.=has_key(a:opts, 'files')
    let cid.=string(a:template)[2:-3]
    if has_key(s:compilecache, cid)
        return s:compilecache[cid]
    endif
    "▶3 Define variables
    let func=['function d.template(cs, opts)',
                \'let r={"text": [], "special": {}}',
                \'let text=r.text',
                \'let special=r.special',]
    let hasfiles=has_key(a:opts, 'files')
    if hasfiles
        let func+=['let files=a:opts.csfiles[a:cs.hex]']
    endif
    let hasrevisions=get(a:opts.repo, 'hasrevisions', 1)
    if get(a:opts, 'patch', 0) || get(a:opts, 'stat', 0)
        let filesarg=((hasfiles && !has_key(a:opts.ignorefiles, 'patch'))?
                    \   ('files'):
                    \   ('[]'))
        let func+=['if !empty(a:cs.parents)',
                    \'let diff=a:opts.repo.functions.diff(a:opts.repo, '.
                    \                                    'a:cs.hex, '.
                    \                                    'a:cs.parents[0], '.
                    \                                     filesarg.', '.
                    \                                    'a:opts)',
                    \'endif']
    endif
    "▲3
    for [lit; meta] in a:template
        if s:F.temp.skip(meta, a:opts)
            continue
        endif
        let addedif=0
        let lmeta=len(meta)
        if lmeta
            let kw=meta[0][0]
            let lkw=meta[-1][0]
        endif
        "▶3 Skip line under certain conditions
        if !lmeta
        elseif lmeta==1 && !s:kwexpr[meta[0][0]][0]
            if index(s:kwpempt, kw)!=-1
                let addedif=1
                let func+=['if !empty(a:cs.'.kw.')']
            elseif kw is# 'branch'
                let addedif=1
                let func+=['if a:cs.branch isnot# "default"']
            elseif kw is# 'rev' && !hasrevisions
                continue
            endif
            let func+=['let special.'.meta[0][0].'_l=[len(text), 0]']
        elseif lkw is# 'patch' || lkw is# 'stat'
            let addedif=1
            let func+=['if exists("diff")']
        elseif lkw is# 'files' || lkw is# 'changes'
            let addedif=1
            let func+=['if !empty(a:cs.'.kw.')']
        endif
        "▲3
        let func+=['let text+=[""]']
        let i=-1
        for str in lit
            let i+=1
            if !empty(str)
                let func+=['let text[-1].='.string(str)]
            endif
            if lmeta>i
                "▶3 Define variables
                let [kw, arg]=meta[i]
                let ke=s:kwexpr[kw]
                "▶3 Get expression
                if has_key(arg, 'expr')
                    let expr=arg.expr
                else
                    let expr=ke[1]
                endif
                "▶4 Determine what should be used as {word} argument
                if has_key(s:kwmarg, kw)
                    let marg=s:kwmarg[kw]
                elseif hasfiles && (kw is# 'files' || kw is# 'changes') &&
                            \!has_key(a:opts.ignorefiles, 'files')
                    let marg='files'
                elseif hasfiles && (kw is# 'renames' || kw is# 'copies') &&
                            \!has_key(a:opts.ignorefiles, kw)
                    let marg='filter(copy(a:cs.'.kw.'), '.
                                \   '"index(files, v:val)!=-1")'
                else
                    let marg='a:cs.'.kw
                endif
                "▲4
                let expr=substitute(expr, '@@@', marg, 'g')
                "▶3 Get positional parameters if required
                let j=0
                for a in ke[2:]
                    let s=get(arg, j, a)
                    let arg[j]=s
                    if s is 0
                        call s:_f.throw('argmis', j, kw)
                    endif
                    let expr=substitute(expr, '@'.j.'@',
                                \       escape(string(s), '&~\'), 'g')
                    let j+=1
                endfor
                "▶3 Skip meta if required
                if kw is# 'rev' && !hasrevisions && arg.0 isnot# 'keep'
                    continue
                endif
                "▶3 Add complex multiline statement
                let addedif2=0
                if ke[0]==2
                    "▶4 Add missing if’s
                    if !addedif
                        if kw is# 'stat'
                            let addedif2=1
                            let func+=['if exists("diff")']
                        elseif kw is# 'files' || kw is# 'changes'
                            let addedif2=1
                            let func+=['if !empty(a:cs.'.kw.')']
                        endif
                    endif
                    "▲4
                    let expr=substitute(expr, '@<@', 'lstr', 'g')
                    let func+=['let lstr=remove(text, -1)',
                                \'let [ntext, sp]='.expr]+
                                \   (has_key(arg, 'flbeg')?
                                \       ['let ntext[0]='.string(arg.flbeg).
                                \                                  '.ntext[0]']:
                                \       [])+[
                                \'call s:F.glog.addlines(sp, len(text))',
                                \'let text+=ntext',
                                \'call extend(special, sp)']
                "▶3 Add simple multiline statement
                elseif ke[0]
                    "▶4 Add missing if’s
                    if !addedif && kw is# 'patch'
                        let addedif2=1
                        let func+=['if exists("diff")']
                    endif
                    "▲4
                    let func+=['let ntext='.expr,
                                \'call map(ntext, '.
                                \         'string(remove(text, -1)).".v:val")']+
                                \   (has_key(arg, 'flbeg')?
                                \       ['let ntext[0]='.string(arg.flbeg).
                                \                                  '.ntext[0]']:
                                \       [])+[
                                \'let special.'.kw.'_R=[[len(text), 0], '.
                                \                '[len(text)+len(ntext)-1, 0]]',
                                \'let text+=ntext']
                "▶3 Add single-line statement
                else
                    if kw is# 'branch' && arg.0 isnot# 'keep'
                        let func+=['if a:cs.branch isnot# "default"']
                    endif
                    let func+=['let estr='.expr]
                    "▶4 Add suffix or prefix
                    if index(s:kwpempt, kw)!=-1
                        let condition='!empty(estr)'
                    elseif kw is# 'branch'
                        let condition='estr isnot# "default"'
                    elseif kw is# 'rev'
                        let condition=0
                    endif
                    if exists('condition')
                        let addif=(condition isnot 0) &&
                                    \(has_key(arg, 'pref') ||
                                    \ has_key(arg, 'suf'))
                        if addif
                            let func+=['if '.condition]
                        endif
                        if has_key(arg, 'pref')
                            let func+=['let estr='.string(arg.pref).'.estr']
                        endif
                        if has_key(arg, 'suf')
                            let func+=['let estr.='.string(arg.suf)]
                        endif
                        if addif
                            let func+=['endif']
                        endif
                    endif
                    "▲4
                    let func+=['let special.'.kw.'_r='.
                                \  '[[len(text)-1, len(text[-1])], '.
                                \   '[len(text)-1, len(text[-1])+len(estr)-1]]',
                                \'let text[-1].=estr',]
                    if kw is# 'branch' && arg.0 isnot# 'keep'
                        let func+=['endif']
                    endif
                endif
                "▲3
                if addedif2
                    let func+=['endif']
                endif
            endif
        endfor
        if addedif
            let func+=['endif']
        endif
    endfor
    let func+=['return r',
                \'endfunction']
    let d={}
    execute join(func, "\n")
    let s:compilecache[cid]=d.template
    return d.template
endfunction
"▶2 temp.addgroup
function s:F.temp.addgroup(r, nlgroups, group)
    let i=0
    for [line, lnr] in filter(map(copy(a:r), '[v:val, v:key]'),
                \             'stridx(",=", v:val[0][-1:])!=-1')
        let a:r[lnr].=a:group
        let i+=1
    endfor
    if !i
        call add(a:nlgroups, a:group)
    endif
endfunction
"▶2 temp.syntax :: template, opts → [VimCommand] + :syn
"▶3 Some globals
let s:syncache={}
let s:noargtimereg='\v\d\d \S+ \d{4,} \d\d:\d\d'
let s:ukntkws=['c', 'x', 'X', '+']
let s:timekwregs={
            \'a': '\S\{1,3}',
            \'A': '\S\+',
            \'b': '\S\{1,3}',
            \'B': '\S\+',
            \'C': '\d\d',
            \'d': '\d\d',
            \'D': '\d\d\/\d\d\/\d\d',
            \'e': '\[1-3 ]\d',
            \'F': '\d\{4,}-\d\d-\d\d',
            \'G': '\d\{4,}',
            \'g': '\d\d',
            \'h': '\S\{1,3}',
            \'H': '\d\d',
            \'I': '\d\d',
            \'j': '\d\{3}',
            \'k': '\[12 ]\d',
            \'l': '\[1 ]\d',
            \'m': '\d\d',
            \'M': '\d\d',
            \'n': '\n',
            \'p': '\[AP]M',
            \'P': '\[ap]m',
            \'r': '\d\d:\d\d:\d\d \[AP]M',
            \'R': '\d\d:\d\d',
            \'s': '\d\+',
            \'S': '\d\d',
            \'t': '\t',
            \'T': '\d\d:\d\d:\d\d',
            \'u': '\[1-7]',
            \'U': '\d\d',
            \'V': '\d\d',
            \'w': '\[0-6]',
            \'W': '\d\d',
            \'y': '\d\d',
            \'Y': '\d\{4,}',
            \'z': '\[+\-]\d\{4}',
            \'Z': '\S\{3}',
            \'%': '%',
        \}
"▲3
function s:F.temp.syntax(template, opts)
    "▶3 Cache
    let cid=string(a:opts.templatefunc)[10:-3]
    if has_key(s:syncache, cid)
        return s:syncache[cid]
    endif
    "▶3 Define variables
    let r=[]
    let topgroups=[]
    let hasrevisions=get(a:opts.repo, 'hasrevisions', 1)
    "▲3
    let r+=['syn match auLogFirstLineStart =\v^[^ ]*[@o][^ ]* = '.
                \'skipwhite nextgroup=']
    let i=0
    let nlgroups=[]
    for [lit; meta] in a:template
        if s:F.temp.skip(meta, a:opts)
            continue
        endif
        let lmeta=len(meta)
        let llit=len(lit)
        let j=0
        let hasmult=0
        for str in lit
            if !empty(str)
                if lmeta>j
                    let skname='SkipBefore_'.meta[j][0]
                else
                    let skname='Text'.i
                endif
                let skname='auLog'.skname
                call s:F.temp.addgroup(r, nlgroups, skname)
                let r+=['syn match '.skname.' ']
                if lmeta>j
                    let r[-1].='/\V'.escape(str, '\/').'/'
                else
                    let r[-1].='/\v.*/'
                endif
                let r[-1].=' contained nextgroup='
            endif
            if lmeta>j
                let [kw, arg]=meta[j]
                if s:kwexpr[kw][0]
                    let hasmult=1
                endif
                if kw is# 'empty' || (kw is# 'rev' && !hasrevisions &&
                            \         arg.0 isnot# 'keep')
                    let r[-1]=substitute(r[-1], '\v\w+$', '', '')
                elseif has_key(arg, 'synreg')
                    call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw)
                    let r+=['syn match auLog_'.kw.' /'.arg.synreg.'/ '.
                                \'contained nextgroup=']
                elseif kw is# 'hex'
                    call s:F.temp.addgroup(r, nlgroups, 'auLogHexStart')
                    let r+=['syn match auLogHexStart /\v\x{12}/ contained'.
                                \' nextgroup=auLogHexEnd',
                            \'syn match auLogHexEnd /\v\x+/ contained '.
                            \   (has('conceal')?('conceal'):('')).' nextgroup=']
                elseif kw is# 'patch'
                    call s:F.temp.addgroup(r, nlgroups,
                                \'auLogPatchAdded,auLogPatchRemoved,'.
                                \'auLogPatchFile,auLogPatchNewFile,'.
                                \'auLogPatchOldFile,auLogPatchOther,'.
                                \'auLogPatchNotModified,'.
                                \'auLogPatchChunkHeader')
                    let newr=[   'Added   /\V+\.\*/',
                                \'Removed /\V-\.\*/',
                                \'File    /\vdiff.*/',
                                \'NewFile /\V+++ \.\*/',
                                \'OldFile /\V--- \.\*/',
                                \'NotModified  / \v.*/',
                                \'ChunkHeader /@\v.*/ contains=auLogPatchSect',
                                \'Sect    /\V @@\.\+/ms=s+3',
                                \]
                    call map(newr, '"syn match auLogPatch".v:val.'.
                                \  '" contained skipnl '.
                                \    'nextgroup=auLogNextLineStart"')
                    let r+=newr
                elseif kw is# 'stat'
                    call s:F.temp.addgroup(r, nlgroups,
                                \'auLogStatFiles,auLogStatFileSep')
                    let newr=[   'Files /\v\d+/ nextgroup=auLogStatFilesMsg',
                                \'FilesMsg / files changed, / '.
                                \              'nextgroup=auLogStatIns',
                                \'Ins /\v\d+/ nextgroup=auLogStatInsMsg',
                                \'InsMsg / insertions, / '.
                                \               'nextgroup=auLogStatDel',
                                \'Del /\v\d+/ nextgroup=auLogStatDelMsg',
                                \'DelMsg / deletions/ skipnl '.
                                \           'nextgroup=auLogNextLineStart',
                                \'FileSep /  / nextgroup=auLogStatFile',
                                \'File /\v%(%(\ \|\ )@!.)+/ '.
                                \             'nextgroup=auLogStatTSep',
                                \'TSep /\v\s+\|\s+/ nextgroup=auLogStatTIns',
                                \'TIns /\v\d+/ nextgroup=auLogStatTNumSep',
                                \'TNumSep /\v\s+/ nextgroup=auLogStatTDel',
                                \'TDel /\v\d+/ skipnl '.
                                \           'nextgroup=auLogNextLineStart']
                    call map(newr, '"syn match auLogStat".v:val.'.
                                \  '" contained"')
                    let r+=newr
                elseif kw is# 'hide'
                    let sname='auLog_hide'.i.'_'.j
                    call s:F.temp.addgroup(r, nlgroups, sname)
                    let r+=['hi def link '.sname.' Ignore']
                    let r+=['syn match '.sname.' /\V'.escape(arg[0], '\/').'/ '.
                                \'contained nextgroup=']
                elseif (index(s:kwpempt, kw)!=-1 || kw is# 'branch' ||
                            \                       kw is# 'rev') &&
                            \(has_key(arg, 'pref') || has_key(arg, 'suf'))
                    if has_key(arg, 'pref')
                        call s:F.temp.addgroup(r,nlgroups,'auLog_'.kw.'_pref,')
                        let r+=['syn match auLog_'.kw.'_pref '.
                                    \'/\V'.escape(arg.pref, '\/').'/ '.
                                    \'contained nextgroup=auLog_'.kw]
                    else
                        call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw.',')
                    endif
                    let nextlit=get(arg, 'suf', get(lit, j+1, 0))
                    let r+=['syn match auLog_'.kw.' '.
                                \'/'.s:F.getkwreg(kw, nextlit).'/ '.
                                \'contained nextgroup=']
                    if has_key(arg, 'suf')
                        let r[-1].='auLog_'.kw.'_suf'
                        let r+=['syn match auLog_'.kw.'_suf '.
                                    \'/\V'.escape(arg.suf, '\/').'/ '.
                                    \'contained nextgroup=']
                    endif
                elseif lmeta==j+1 && llit<=j+1
                    call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw)
                    let r+=['syn match auLog_'.kw.' /\v.*/ '.
                                \'contained nextgroup=']
                elseif kw is# 'time'
                    call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw)
                    if has_key(arg, 0)
                        if j<=llit && !empty(lit[j+1])
                            let creg='\%(\%('.escape(lit[j+1], '\/').'\)\@!'.
                                        \'\.\)\*'
                        else
                            let creg='\.\*'
                        endif
                        let reg='\V'.substitute(escape(arg.0, '\/'), '\v\%(.)',
                                    \'\=index(s:ukntkws, submatch(1))==-1 ?'.
                                    \   'get(s:timekwregs, submatch(1), '.
                                    \       'submatch(0)) :'.
                                    \   'creg', 'g')
                    else
                        let reg=s:noargtimereg
                    endif
                    let r+=['syn match auLog_time '.
                                \'/'.reg.'/ '.
                                \'contained nextgroup=']
                else
                    call s:F.temp.addgroup(r, nlgroups, 'auLog_'.kw)
                    let r+=['syn match auLog_'.kw.' /'.
                                \s:F.getkwreg(kw, get(lit, j+1, 0)).'/ '.
                                \'contained nextgroup=']
                endif
            endif
            let j+=1
        endfor
        call s:F.temp.addgroup(r, nlgroups, 'auLogNextLineStart')
        let r[-1].=' skipnl'
        let i+=1
    endfor
    if !empty(nlgroups)
        let r+=['syn match auLogNextLineStart @\v^[^ ]+ @ skipwhite '.
                    \' nextgroup='.join(nlgroups, ',')]
    endif
    call add(r, remove(r, 0))
    if len(r)==1
        return []
    endif
    let s:syncache[cid]=r
    return r
endfunction
"▶1 comparedates :: datesel, time → -1|0|1
let s:datechars='YmdHM'
function s:F.comparedates(datesel, time)
    let j=0
    for selnum in split(a:datesel, '\v[^0-9*.]+')
        if selnum isnot# '*'
            let spec='%'.s:datechars[j]
            if selnum is# '.'
                let selnum=str2nr(strftime(spec))
            else
                if j==0 && len(selnum)==2
                    let y=str2nr(selnum)
                    let cy=str2nr(strftime('%y'))
                    let c=str2nr(strftime('%Y')[:-3])
                    if y<=cy
                        let selnum=((c*100)+y)
                    else
                        let selnum=(((c-1)*100)+y)
                    endif
                else
                    let selnum=str2nr(selnum)
                endif
            endif
            let actnum=str2nr(strftime(spec, a:time))
            if actnum!=selnum
                if actnum<selnum
                    return -1
                else
                    return 1
                endif
            endif
        endif
        let j+=1
    endfor
    return 0
endfunction
"▶1 setup
"▶2 trackfile :: repo, cs, file, csfiles → + csfiles
function s:F.trackfile(repo, cs, file, csfiles)
    let tocheck=[[a:file, a:cs]]
    while !empty(tocheck)
        let [file, cs]=remove(tocheck, 0)
        if !has_key(a:csfiles, cs.hex)
            continue
        endif
        let rename=get(cs.renames, file, 0)
        if type(rename)!=type('')
            let rename=file
        endif
        let copy=get(cs.copies, file, 0)
        if type(copy)==type('')
            if index(cs.changes, file)!=-1 && index(a:csfiles[cs.hex], file)==-1
                let a:csfiles[cs.hex]+=[copy]
            endif
            let tocheck+=map(copy(cs.parents),'[copy,a:repo.changesets[v:val]]')
        endif
        if index(a:repo.functions.getcsprop(a:repo, cs, 'allfiles'), file)==-1
            continue
        endif
        if index(cs.changes, file)!=-1 && index(a:csfiles[cs.hex], file)==-1
            let a:csfiles[cs.hex]+=[file]
        endif
        let tocheck+=map(copy(cs.parents), '[rename, a:repo.changesets[v:val]]')
    endwhile
endfunction
"▶2 getkwreg
function s:F.getkwreg(kw, nextlit)
    if has_key(s:kwreg, a:kw)
        return s:kwreg[a:kw]
    " XXX 0 is empty
    elseif !empty(a:nextlit)
        return '\V\%(\%('.escape(a:nextlit, '\/').'\)\@!\.\)\*'
    else
        return '.*'
    endif
endfunction
"▲2
function s:F.setup(read, repo, opts)
    let opts=a:opts
    let bvar={}
    call a:repo.functions.getchangesets(a:repo)
    "▶2 Add `ignorefiles'
    let ignorefiles=(has_key(opts, 'ignfiles')?
                \               (opts.ignfiles):
                \               (s:_f.getoption('ignorefiles')))
    let opts.ignorefiles={}
    call map(copy(ignorefiles), 'extend(opts.ignorefiles, {v:val : 1})')
    unlet ignorefiles
    "▶2 Get revision range
    if has_key(opts, 'revrange')
        let opts.revs=map(copy(opts.revrange),
                    \'a:repo.changesets['.
                    \   'a:repo.functions.getrevhex(a:repo, v:val)].hex')
    elseif get(opts, 'limit', 0)>0
        let opts.revs=[-opts.limit, -1]
    else
        let opts.revs=[0, -1]
    endif
    "▶2 Process `revision' option
    if has_key(opts, 'revision')
        let hex=a:repo.functions.getrevhex(a:repo, opts.revision)
        let cs=a:repo.changesets[hex]
        if type(cs.rev)==type(0) && cs.rev<opts.revs[1]
            let opts.revs[1]=cs.hex
        endif
        let opts.revisions={}
        let addrevs=[cs]
        while !empty(addrevs)
            let cs=remove(addrevs, 0)
            if has_key(opts.revisions, cs.hex)
                continue
            endif
            let opts.revisions[cs.hex]=1
            let addrevs+=map(copy(cs.parents), 'a:repo.changesets[v:val]')
        endwhile
    endif
    "▲2
    let css=a:repo.functions.revrange(a:repo, opts.revs[0], opts.revs[1])
    "▶2 Generate cs.{kw} for various options (`show{kw}'+`files')
    for key in ['renames', 'copies']
        if get(opts, 'show'.key, 0) || has_key(opts, 'files')
            for cs in css
                call a:repo.functions.getcsprop(a:repo, cs, key)
            endfor
        endif
    endfor
    "▶2 Generate cs.files for several options
    if has_key(opts, 'files') || get(opts, 'showrenames', 0) ||
                \                get(opts, 'showcopies',  0) ||
                \                get(opts, 'showfiles',   0) ||
                \                get(opts, 'stat',        0)
        for cs in css
            call a:repo.functions.getcsprop(a:repo, cs, 'files')
        endfor
    endif
    "▶2 Generate cs.changes for showfiles option
    if has_key(opts, 'files') || get(opts, 'showfiles', 0)
        for cs in css
            call a:repo.functions.getcsprop(a:repo, cs, 'changes')
        endfor
    endif
    "▶2 Generate file lists for `files' option
    if has_key(opts, 'files')
        let opts.csfiles={}
        for cs in css
            let changes=copy(cs.changes)
            let csfiles=[]
            let opts.csfiles[cs.hex]=csfiles
            for pattern in opts.filepats
                let newfiles=filter(copy(changes), 'v:val=~#pattern')
                call filter(changes, 'index(newfiles, v:val)==-1')
                let csfiles+=newfiles
                if empty(changes)
                    break
                endif
            endfor
            call map(copy(csfiles), 's:F.trackfile(a:repo, cs, v:val, '.
                        \                         'opts.csfiles)')
        endfor
        let opts.totrack={}
    endif
    "▶2 Narrow changeset range
    let opts.skipchangesets={}
    let firstnoskip=-1
    let foundfirst=0
    let lastnoskip=-1
    let i=opts.revs[0]
    let requires_sort=get(a:repo, 'requires_sort', 1)
    for cs in css
        let skip=0
        "▶3 `branch', `merges', `search', `user', `revision'
        if (has_key(opts, 'branch') && cs.branch isnot# opts.branch)||
                    \(has_key(opts, 'merges') &&
                    \   ((opts.merges)?(len(cs.parents)<=1):
                    \                  (len(cs.parents)>1))) ||
                    \(has_key(opts, 'search') &&
                    \   cs.description!~#opts.search) ||
                    \(has_key(opts, 'user') && cs.user!~#opts.user) ||
                    \(has_key(opts, 'revision') &&
                    \   !has_key(opts.revisions, cs.hex))
            let skip=1
        "▶3 `date'
        elseif has_key(opts, 'date')
            if match(opts.date, '\V<=\?>')!=-1
                let [date1, date2]=split(opts.date, '\V<=\?>')
                let acceptexact=(stridx(opts.date, '<=>', len(date1))!=-1)
                let cmp1result=s:F.comparedates(date1, cs.time)
                let cmp2result=s:F.comparedates(date2, cs.time)
                if !((cmp1result==1 && cmp2result==-1) ||
                            \(acceptexact && (cmp1result==0 ||
                            \                 cmp2result==0)))
                    let skip=1
                endif
            else
                let selector=opts.date[0]
                let acceptexact=(stridx('<>', selector)==-1 || opts.date[1] is# '=')
                let cmpresult=s:F.comparedates(opts.date, cs.time)
                if !((acceptexact && cmpresult==0) ||
                            \(selector is# '<' && cmpresult==-1) ||
                            \(selector is# '>' && cmpresult==1))
                    let skip=1
                endif
            endif
        endif
        "▶3 `files'
        if !skip && has_key(opts, 'files')
            let files=opts.csfiles[cs.hex]
            if empty(files)
                let skip=1
            endif
        endif
        "▲3
        if requires_sort
            if skip
                let opts.skipchangesets[cs.hex]=cs
            endif
        elseif skip
            if foundfirst
                let opts.skipchangesets[cs.hex]=cs
            endif
        else
            if foundfirst
                let lastnoskip=cs.hex
            else
                let foundfirst=1
                let firstnoskip=cs.hex
            endif
        endif
        let i+=1
    endfor
    if firstnoskip!=-1
        let opts.revs[0]=firstnoskip
    endif
    if lastnoskip!=-1
        let opts.revs[1]=lastnoskip
    endif
    "▶2 Get template
    if has_key(opts, 'template')
        let template=eval(opts.template)
    elseif has_key(opts, 'style')
        let template=s:templates[opts.style]
    else
        let template=s:templates.default
    endif
    let opts.repo=a:repo
    let bvar.templatelist=s:F.temp.parse(template)
    let opts.templatefunc=s:F.temp.compile(bvar.templatelist, opts)
    "▲2
    let css=a:repo.functions.revrange(a:repo, opts.revs[0], opts.revs[1])
    let text=s:F.glog.graphlog(a:repo, opts, css)
    let bvar.specials=text.specials
    let bvar.rectangles=text.rectangles
    let bvar.csstarts=text.csstarts
    let bvar.cw=s:_f.getoption('closewindow')
    if !a:read
        setlocal noreadonly modifiable
    endif
    call s:_r.setlines(text.text, a:read)
    if !a:read
        setlocal readonly nomodifiable buftype=nofile
        augroup AuLogNoInsert
            autocmd InsertEnter <buffer> :call feedkeys("\e", "n")
        augroup END
    endif
    return bvar
endfunction
let s:_augroups+=['AuLogNoInsert']
"▶1 syndef
function s:F.syndef()
    let buf=+expand('<abuf>')
    if !has_key(s:_r.bufvars, buf)
        return
    endif
    let bvar=s:_r.bufvars[buf]
    let bvar.templatesyn=s:F.temp.syntax(bvar.templatelist, bvar.opts)
    for line in bvar.templatesyn
        execute line
    endfor
endfunction
augroup auLogSyntax
    autocmd Syntax aurumlog :call s:F.syndef()
augroup END
let s:_augroups+=['auLogSyntax']
"▶1 logfunc
function s:logfunc.function(repopath, opts)
    let opts=copy(a:opts)
    if has_key(opts, 'files')
        if opts.files[0] is# ':'
            let curfile=s:_r.cmdutils.getrrf(opts, 'nocurf', -1)[3]
            if curfile is 0
                call remove(opts.files, 0)
            else
                let opts.files[0]=s:_r.cmdutils.globescape(curfile)
            endif
        endif
        if a:repopath is# ':'
            let repo=s:_r.repo.get(opts.files[0])
        else
            let repo=s:_r.repo.get(a:repopath)
        endif
        call map(opts.files, 'repo.functions.reltorepo(repo, v:val)')
    else
        let repo=s:_r.repo.get(a:repopath)
    endif
    call s:_r.cmdutils.checkrepo(repo)
    if has_key(opts, 'cmd')
        let cmd=remove(opts, 'cmd')
    else
        let cmd='silent new'
    endif
    call s:_r.run(cmd, 'log', repo, opts)
    if !has_key(opts, 'cmd')
        setlocal bufhidden=wipe
    endif
endfunction
let s:datereg='%(\d\d%(\d\d)?|[*.])'.
            \ '%(\-%(\d\d?|[*.])'.
            \ '%(\-%(\d\d?|[*.])'.
            \ '%([ _]%(\d\d?|[*.])'.
            \ '%(\:%(\d\d?|[*.]))?)?)?)?'
let s:logfunc['@FWC']=['-onlystrings '.
            \          '['.s:_r.cmdutils.nogetrepoarg.']'.
            \          '{ *?files    (type "")'.
            \          '  *?ignfiles in [patch renames copies files] ~start'.
            \          '   ?date     match /\v[<>]?\=?'.s:datereg.'|'.
            \                                 s:datereg.'\<\=?\>'.s:datereg.'/'.
            \          '   ?search   isreg'.
            \          '   ?user     isreg'.
            \          '   ?branch   type ""'.
            \          '   ?limit    range 1 inf'.
            \          '   ?revision type ""'.
            \          ' +2?revrange type "" type ""'.
            \          '   ?style    key templates'.
            \          '   ?template idof variable'.
            \          '  !?merges'.
            \          '  !?patch'.
            \          '  !?stat'.
            \          '  !?showfiles'.
            \          '  !?showrenames'.
            \          '  !?showcopies'.
            \          s:_r.repo.diffoptsstr.
            \          '   ?cmd      type ""'.
            \          '}', 'filter']
call add(s:logcomp, substitute(substitute(
            \substitute(substitute(substitute(substitute(s:logfunc['@FWC'][0],
            \'\V|*_r.repo.get',        '',                                  ''),
            \'\vfiles\s+\([^)]*\)',    'files path',                        ''),
            \'\Vcmd\s\+type ""',       'cmd first (in cmds, idof command)', ''),
            \'\vrevision\s+\Vtype ""', 'revision '.s:_r.comp.rev,           ''),
            \'\vbranch\s+\Vtype ""',   'branch '.s:_r.comp.branch,          ''),
            \'\vrevrange\s+\Vtype "" type ""',
            \                         'revrange '.s:_r.comp.rev.' '.
            \                                     s:_r.comp.rev,            ''))
"▶1 Post resource
call s:_f.newcommand({
            \'function': s:F.setup,
            \ 'options': {'list': ['files', 'revrange', 'ignfiles'],
            \             'bool': ['merges', 'patch', 'stat', 'showfiles',
            \                      'showrenames', 'showcopies'],
            \              'num': ['limit']+s:_r.repo.diffoptslst,
            \              'str': ['date', 'search', 'user', 'branch',
            \                      'revision', 'style', 'template',
            \                      'crrestrict'],
            \             'pats': ['files'],
            \            },
            \'filetype': 'aurumlog',
            \})
"▶1
call frawor#Lockvar(s:, '_r,_pluginloaded,compilecache,parsecache,syncache')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
