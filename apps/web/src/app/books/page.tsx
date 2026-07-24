import {Breadcrumbs,PageHeader} from '@/components/layout/Page';import {BookManagement} from '@/features/books/BookManagement';
export default function Books(){return <><Breadcrumbs items={[{label:'Dashboard',href:'/dashboard'},{label:'Books'}]}/><PageHeader title="Books" description="Create and manage publication projects, editions, structures and milestones."/><BookManagement/></>}
