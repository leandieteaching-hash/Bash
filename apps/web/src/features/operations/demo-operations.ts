import type {OperationsSnapshot} from './types';
export const demoOperations:OperationsSnapshot={generatedAt:new Date().toISOString(),services:[
{id:'database',name:'PostgreSQL',state:'healthy',latencyMs:34,uptime:99.99,lastChecked:'Just now',detail:'Primary database accepting reads and writes.'},
{id:'storage',name:'Supabase Storage',state:'healthy',latencyMs:88,uptime:99.97,lastChecked:'Just now',detail:'Private asset and export buckets available.'},
{id:'realtime',name:'Realtime',state:'healthy',latencyMs:61,uptime:99.96,lastChecked:'Just now',detail:'Publication channels connected.'},
{id:'workers',name:'Background workers',state:'warning',latencyMs:240,uptime:99.81,lastChecked:'1 min ago',detail:'Two export jobs are retrying.'},
{id:'email',name:'Email delivery',state:'healthy',latencyMs:130,uptime:99.94,lastChecked:'1 min ago',detail:'Delivery queue within target.'},
{id:'backups',name:'Backups',state:'healthy',latencyMs:0,uptime:100,lastChecked:'18 min ago',detail:'Latest encrypted backup verified.'}
],metrics:{apiP95Ms:184,errorRate:0.18,queueDepth:7,storageUsedGb:286,backupAgeHours:0.3,activeUsers:42},incidents:[{id:'inc-01',severity:'warning',title:'Two CMYK exports retrying',status:'acknowledged',startedAt:'09:42',owner:'Production Ops'}]};
