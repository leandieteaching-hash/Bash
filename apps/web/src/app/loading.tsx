export default function Loading(){return <div className="grid">{[1,2,3,4].map(i=><div key={i} className="card metric" style={{height:120,opacity:.55}}/>)}</div>}
