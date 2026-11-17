import json, os, re, sys, hashlib
src = sys.argv[1]; out = sys.argv[2]
MP_CC = {
 '313.FM':'US','9128.live':'GB','AM-Ambient':'US','AfterhoursFM':'NL','AmbientSleepingPill':'US','BBC-Radio-Stations':'GB',
 'BBC-WorldService':'GB','BadRadio':'US','Bluemars-Cryosleep':'CH','Bluemars-VoicesFromWithin':'CH','Bluemars':'CH',
 'CashmereRadio':'DE','DandelionRadio':'GB','DarkAmbientRadio':'US','DialRadio':'DE','DoYouRadio':'IT','Dogglounge':'US',
 'Doubleclap':'DE','Dublab':'US','FIP-Stations':'FR','Frisky-Chill':'US','Frisky-Deep':'US','Frisky':'US',
 'Hirschmilch-Stations':'DE','IntergalacticFM-Stations':'NL','KAFM-WesternCO-Public':'US','KALX-Berkeley':'US','KCHUNG':'US',
 'KEXP-Seattle':'US','KPISS':'US','KSPC-Claremont':'US','KXLU-SoCalLoyolaMarymount':'US','KioskRadio':'BE','LeMellotron':'FR',
 'NASA-ThirdRockRadio':'US','NTS1':'GB','NTS2':'GB','Nectarine':'FR','NewtownRadio':'US','NightwavePlaza':'ZZ','Noods-Radio':'GB',
 'RadioCaroline':'GB','RadioParadise-Global':'US','RadioParadise-MainMix':'US','RadioRivendell':'SE','Radiomeuh':'FR',
 'RePlayScape':'ZZ','RinseFM':'GB','SanctuaryRadio':'GB','ShonenBeachFM':'JP','Slay-Radio':'SE','SleepbotEnvironmental':'US',
 'Sleepscapes-Rain':'ZZ','Sleepscapes-Waves':'ZZ','SohoRadio':'GB','SomaFM-DeepSpaceOne':'US','SomaFM-DroneZone':'US',
 'SomaFM-GrooveSalad':'US','SomaFM-Lush':'US','SomaFM-SF10-33':'US','SomaFM-SpaceStation':'US','Subcity':'GB',
 'SyntheticFM-NewItaloDisco':'DE','SyntheticFM-Synth':'DE','TheLotRadio':'US','WFMU-Jersey-City':'US','WorldwideFM':'GB'}
def sid(url): return 'cur-' + hashlib.sha1(url.encode()).hexdigest()[:16]
def parse(path):
    """yield dicts with name, urls, home, logo, group, tags, radio, ua"""
    cur=None; home=None; group=None; ua=None
    res=[]
    for line in open(path, encoding='utf-8-sig', errors='replace'):
        line=line.strip()
        if not line: continue
        if line.startswith('# Group:'): group=line[8:].strip(); continue
        if line.startswith('# Homepage:'): home=line[11:].strip(); continue
        if line.startswith('#EXTINF'):
            attrs=dict(re.findall(r'([\w-]+)="([^"]*)"', line))
            name=line.rsplit(',',1)[-1].strip() if ',' in line else ''
            cur={'name':name,'urls':[],'home':home or '','logo':attrs.get('tvg-logo',''),
                 'group':attrs.get('group-title',group or ''),'radio':attrs.get('radio'),'genre':'','ua':''}
            res.append(cur); home=None; continue
        if line.startswith('#EXTGENRE:') and cur: cur['genre']=line[10:].strip(); continue
        if line.startswith('#EXTVLCOPT:http-user-agent=') and cur:
            cur['ua']=line.split('=',1)[1].strip('"'); continue
        if line.startswith('#'): continue
        if cur is not None and re.match(r'https?://', line): cur['urls'].append(line)
    return [r for r in res if r['urls']]
stations=[]
d='%s/recommended-radio-streams/playlists'%src
for f in sorted(os.listdir(d)):
    if f.startswith('news-') or f.startswith('experimental-'): continue
    for r in parse(os.path.join(d,f)):
        stations.append({'id':sid(r['urls'][0]),'name':r['name'],'url':r['urls'][0],'alt':r['urls'][1:],'home':r['home'],
          'logo':'','cc':'ZZ','country':'International','tags':(r['group'] or '').replace('&',',').lower(),'src':'cur'})
d='%s/internet-radio-streams'%src
for f in sorted(os.listdir(d)):
    if not f.endswith('.m3u'): continue
    base=f[:-4]; cc=MP_CC.get(base,'ZZ')
    entries=parse(os.path.join(d,f))
    for r in entries:
        nm=r['name'] or base.replace('-',' ')
        stations.append({'id':sid(r['urls'][0]),'name':nm,'url':r['urls'][0],'alt':r['urls'][1:],'home':'','logo':'',
          'cc':cc,'country':'','tags':r['genre'].lower(),'src':'cur'})
for r in parse('%s/M3UPT/M3U/M3UPT.m3u'%src):
    if r['radio']!='true': continue
    stations.append({'id':sid(r['urls'][0]),'name':r['name'],'url':r['urls'][0],'alt':r['urls'][1:],'home':'','logo':r['logo'],
      'cc':'PT','country':'Portugal','tags':'','src':'cur','ua':r['ua']})
# drop empty fields
seen=set(); outl=[]
for s in stations:
    if s['id'] in seen: continue
    seen.add(s['id']); outl.append({k:v for k,v in s.items() if v not in ('',[],None)})
json.dump({'generated':'2026-11-17','stations':outl}, open(out,'w'), ensure_ascii=False, indent=0)
print(len(outl))
