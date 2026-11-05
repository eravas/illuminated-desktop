function context(monitors, allTags, clients, name, allOutputs, healthy) {
    const monitor = monitors.find(m => m.name === name);
    if (!monitor || !healthy) return {ready:false, modelKind:"tags", monitorName:name, monitorFocused:false, spaces:[], selection:[]};
    const groups = allTags.filter(g => allOutputs || g.monitor === name);
    const spaces = [];
    groups.forEach(group => (group.tags || []).forEach(tag => {
        const members = clients.filter(c => c.monitor === group.monitor && Array.isArray(c.tags) && c.tags.indexOf(tag.index) >= 0 && !c.is_scratchpad && !c.is_namedscratchpad);
        spaces.push({id:tag.index, name:String(tag.index), kind:"tag", output:group.monitor, active:!!tag.is_active,
            focused:!!tag.is_active && group.monitor === name && !!monitor.active,
            urgent:!!tag.is_urgent, count:tag.client_count, toplevels:{values:members}});
    }));
    const selected = (monitor.active_tags || []).slice();
    return {ready:true, modelKind:"tags", monitorName:name, monitorFocused:!!monitor.active, spaces:spaces, selection:selected, overview:selected.indexOf(0) >= 0};
}
function selection(current, tag, extend) {
    if (!Number.isInteger(tag) || tag < 1 || tag > 31) return [];
    if (!extend) return [tag];
    const result = current.indexOf(tag) >= 0 ? current.filter(t => t !== tag) : current.concat([tag]);
    return result.length ? result.sort((a,b) => a-b) : current.slice();
}
