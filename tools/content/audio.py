"""Original synthesized mono cues; no sampled or third-party recordings.
Builds upload-ready PCM WAVs, with deliberately quiet peaks and bounded durations.
"""
import math, random, struct, wave, json
from pathlib import Path

SPECS = {
 'Shot_sprayline':(.14,220), 'Shot_twin_jets':(.10,320), 'Shot_splash_pot':(.32,140),
 'Shot_popshot':(.35,95), 'Shot_linecaster':(.24,620),
 'Melee_lane_roller':(.35,110), 'Melee_street_sweeper':(.16,250),
 'ChargeStart':(1.1,240), 'ChargeFire':(.35,850), 'Dash':(.18,390),
 'Burst':(.5,75), 'Throw_splash_can':(.22,310), 'Throw_color_burst':(.25,350),
 'Throw_paintstorm':(.25,420), 'UltPrep_color_burst':(.25,480), 'UltPrep_paintstorm':(.25,560),
 'Storm':(.5,130), 'Fizzle':(.35,100), 'LaunchMarker':(.65,660),
 'UI_HitConfirm':(.08,1100), 'UI_ShieldHit':(.15,740), 'Eliminated':(.45,200),
 'Spawn':(.5,440), 'UI_FinalCue':(.7,660), 'UI_RoundEnd':(1.2,330),
 'UI_Countdown':(.14,550), 'UI_RoundStart':(.45,880), 'GlideLoop':(1,170),
 'EmptyClick':(.07,160), 'UI_LowPaint':(.25,500), 'ScreenBreak':(.4,180),
 'UI_Confirm':(.1,780), 'UI_Back':(.1,430), 'Impact':(.12,230),
}

def main():
 out=Path('assets/audio_sources');out.mkdir(parents=True,exist_ok=True)
 records=[]
 for key,(duration,hz) in SPECS.items():
  rng=random.Random(key); samples=[];sr=22050;n=int(duration*sr)
  for i in range(n):
   t=i/sr;u=i/max(1,n-1)
   envelope=min(1,t/.008)*min(1,(duration-t)/.025)*math.exp(-3*u)
   if key=='GlideLoop':envelope=.32*math.sin(math.pi*u)**2
   rising=key in ('ChargeStart','Spawn','UI_RoundStart')
   phase=2*math.pi*hz*(t+(0.8 if rising else -.28)*t*t/duration)
   noise=rng.uniform(-1,1)
   signal=.65*math.sin(phase)+.2*math.sin(phase*1.5)+(.15 if key.startswith('UI_') else .35)*noise
   samples.append(int(max(-1,min(1,signal*envelope*.3))*32767))
  path=out/(key+'.wav')
  with wave.open(str(path),'wb') as f:
   f.setparams((1,2,sr,0,'NONE','not compressed'));f.writeframes(struct.pack('<'+'h'*n,*samples))
  records.append(dict(key=key,source=str(path).replace('\\','/'),duration=duration,assetId=None,owner='Unpublished; intended group 506801379',license='Original project synthesis; no third-party samples',liveLoad='NOT RUN',status='UPLOAD_REQUIRED'))
 Path('assets/audio_manifest.json').write_text(json.dumps(records,indent=2)+'\n')
 print(f'Created {len(records)} original PCM cues')
if __name__=='__main__':main()
