float4 qsqr( in float4 a ) // square a quaterion
{
    return float4( a.x*a.x - a.y*a.y - a.z*a.z - a.w*a.w,
                 2.0*a.x*a.y,
                 2.0*a.x*a.z,
                 2.0*a.x*a.w );
}

void sphereFold(inout float3 z, inout float dz)
{
	float r2 = dot(z,z);
	if (r2 < 0.5)
    { 
		float temp = 2.0;
		z *= temp;
		dz*= temp;
	}
    else if (r2 < 1.0)
    { 
		float temp = 1.0 / r2;
		z *= temp;
		dz*= temp;
	}
}

void boxFold(inout float3 z, inout float dz)
{
	z = clamp(z, -1.0, 1.0) * 2.0 - z;
}

//static mandelbulb
float sdMandelbulb(float3 p)
{
	float3 w = p;
    float m = dot(w, w);

	float dz = 1.0;
        
	for(int i = 0; i < 15; i++)
    {
        dz = 8 * pow(sqrt(m), 7.0)*dz + 1.0;
        float r = length(w);
        float b = 8 * acos(w.y / r);
        float a = 8 * atan2(w.x, w.z);
        w = p + pow(r, 8) * float3(sin(b) * sin(a), cos(b), sin(b) * cos(a));

        m = dot(w, w);
		if(m > 256.0)
            break;
    }
    return 0.25*log(m)*sqrt(m)/dz;
}

float sdDinamMandelbulb(float3 pos, float power)
{
    float3 z = pos;
    float r = 0;
    float dr = 1;
    for(int i = 0; i < 5; i++) 
    {
        r = length(z);
        if(r > 100) break;
        
        float theta = acos(z.z / r);
        float phi = atan2(z.y, z.x);
        
        dr = power * pow(r, power-1)*dr+1;
        
        r = pow(r, power);
        theta *= power;
        phi *= power;
        
        z = r * float3(sin(theta) * cos(phi), 
                sin(theta) * sin(phi), 
                cos(theta));

        z += pos;
    }
    return 0.5 * log(r) * r / dr;

}



float sdJulia(float3 pos, float4 c)
{
	float4 z = float4(pos, 0);
    float md2 = 1;
    float mz2 = dot(z, z);

	[loop]
    for(int i = 0; i < 11; i++)
    {
        md2 *= 4.0 * mz2; // dz -> 2·z·dz, meaning |dz| -> 2·|z|·|dz| (can take the 4 out of the loop and do an exp2() afterwards)
        z = qsqr(z) + c; // z  -> z^2 + c

        mz2 = dot(z,z);

        if(mz2 > 4.0) break;
    }
    
    return 0.25 * sqrt(mz2/md2) * log(mz2);
}

float sdJuliabulb(float3 pos, float4 c)
{
	float3 orbit = pos;
    float dz = 1;
    
    for (int i = 0; i < 4; i++) 
    {
        float r = length(orbit);
    	float o = acos(orbit.z/r);
    	float p = atan(orbit.y/orbit.x);
        
        dz = 8*r*r*r*r*r*r*r*dz;
        
        r = r*r*r*r*r*r*r*r;
        o = 8*o;
        p = 8*p;
        
        orbit = float3(r*sin(o) * cos(p), 
                r*sin(o) * sin(p), 
                r*cos(o)) + c;
        
        if (dot(orbit, orbit) > 4.0) break;
    }
    float z = length(orbit);
    return 0.5*z*log(z)/dz;
}

float sierpinski(float3 p)
{
    const float3 va = float3(  0.0,  0.575735,  0.0 );
    const float3 vb = float3(  0.0, -1.0,  1.15470 );
    const float3 vc = float3(  1.0, -1.0, -0.57735 );
    const float3 vd = float3( -1.0, -1.0, -0.57735 );

    float a = 0;
    float s = 1;
    float r = 1;
    float dm;
    float3 v;
    [loop]
    for(int i = 0; i < 15; i++)
	{
	    float d, t;
		d = dot(p - va, p - va);

        v = va; 
        dm = d; 
        t = 0;
        
        d = dot(p - vb, p - vb); 
        if(d < dm) 
        { 
            v = vb; 
            dm=d; 
            t = 1.0; 
        }
        
        d = dot(p-vc, p-vc); 

        if(d < dm) { v = vc; dm = d; t = 2.0; }
        d = dot(p-vd,p-vd); 
        if(d < dm) { v = vd; dm = d; t = 3.0; }

		p = v + 2*(p - v); 
        r*= 2;
		a = t + 4*a; 
        s*= 4;
	}
	
	return float2((sqrt(dm)-1.0)/r, a/s);
}

float mandelbox(float3 p)
{
    float scale = 2;
	float3 offset = p;
	float dr = 1.0;
	for (int n = 0; n < 10; n++)
    {
		boxFold(p, dr);
		sphereFold(p, dr);
        p = scale * p + offset;
        dr = dr * abs(scale) + 1.0;
	}
	float r = length(p);
	return r / abs(dr);
}

float remap(float value, float low1, float high1, float low2, float high2)
{
    return low2 + (value - low1) * (high2 - low2) / (high1 - low1);
}